# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************

require "yast"
require "shellwords"

module Yast
  # Reads and writes the ifcfg files (/etc/sysconfig/network/ifcfg-*).
  # Categorizes the configurations according to type.
  # Presents them one ifcfg at a time through the {#Current} hash.
  class NetworkInterfacesClass < Module
    attr_reader :Devices

    include Logger

    Yast.import "String"

    # A single character used to separate alias id
    ALIAS_SEPARATOR = "#".freeze
    TYPE_REGEX = "(ip6tnl|mip6mnha|[#{String.CAlpha}]+)".freeze
    ID_REGEX = "([^#{ALIAS_SEPARATOR}]*)".freeze
    ALIAS_REGEX = "(.*)".freeze
    DEVNAME_REGEX = "#{TYPE_REGEX}-?#{ID_REGEX}".freeze

    # @attribute Name
    # @return [String]
    #
    # Current device identifier, like eth0, eth1:blah, lo, ...
    #
    # {#Add}, {#Edit} and {#Delete} copy the requested device info
    # (via {#Select}) to {#Name} and {#Current}, {#Commit} puts it back.

    # @attribute Current
    # @return [Hash<String>]
    #
    # Current device information
    # like { "BOOTPROTO"=>"dhcp", "STARTMODE"=>"auto" }
    #
    # {#Add}, {#Edit} and {#Delete} copy the requested device info
    # (via {#Select}) to {#Name} and {#Current}, {#Commit} puts it back.

    def main
      textdomain "base"

      Yast.import "Arch"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "Netmask"
      Yast.import "FileUtils"
      Yast.import "IP"

      @Name = ""

      @Current = {}

      # Interface information:
      # Devices[string type, string id] is a map with the contents of
      # ifcfg-<i>type</i>-<i>id</i>. Separating type from id is useful because
      # the type determines the fields of the interface file.
      # Multiple addresses for an interface are nested maps
      # [type, id, "_aliases", aid]
      # @see #Read
      @Devices = {}

      # Devices information
      # @see #Read
      @OriginalDevices = {}

      # Deleted devices
      @Deleted = []

      # True if devices are already read
      @initialized = false

      # Which operation is pending?
      # global
      @operation = nil
      # FIXME: used in lan/address.ycp (#17346) -> "global"

      # Predefined network card regular expressions
      @CardRegex =
        # other: irlan|lo|plip|...
        {
          "netcard" => "ath|ci|ctc|slc|dummy|bond|eth|ficon|hsi|qeth|lcs|wlan|xp|vlan|br|tun|tap|ib|em|p|p[0-9]+p",
          "modem"   => "ppp|modem",
          "isdn"    => "isdn|ippp",
          "dsl"     => "dsl"
        }

      # Predefined network device regular expressions
      @DeviceRegex = {
        # device types
        "netcard" => @CardRegex["netcard"],
        "modem"   => @CardRegex["modem"],
        "isdn"    => @CardRegex["isdn"],
        "dsl"     => @CardRegex["dsl"],
        # device groups
        "dialup"  => @CardRegex["modem"] + "|" + @CardRegex["dsl"] + "|" + @CardRegex["isdn"]
      }

      # Types in order from fastest to slowest.
      # @see #FastestRegexps
      @FastestTypes = { 1 => "dsl", 2 => "isdn", 3 => "modem", 4 => "netcard" }

      # -------------------- components of configuration names --------------------

      # ifcfg name = type + id + alias_id
      # If id is numeric, it is not separated from type, otherwise separated by "-"
      # Id may be empty
      # Alias_id, if nonempty, is separated by alias_separator
      @ifcfg_name_regex = "^#{DEVNAME_REGEX}#{ALIAS_SEPARATOR}?#{ALIAS_REGEX}$"

      # Translates type code exposed by kernel in sysfs onto internaly used dev types.
      @TypeBySysfs = {
        "1"     => "eth",
        "24"    => "eth",
        "32"    => "ib",
        "512"   => "ppp",
        "768"   => "ipip",
        "769"   => "ip6tnl",
        "772"   => "lo",
        "776"   => "sit",
        "778"   => "gre",
        "783"   => "irda",
        "801"   => "wlan_aux",
        "65534" => "tun"
      }

      @TypeByKeyValue = ["INTERFACETYPE"]
      @TypeByKeyExistence = [
        ["ETHERDEVICE", "vlan"],
        ["WIRELESS_MODE", "wlan"],
        ["MODEM_DEVICE", "ppp"],
        ["IPOIB_MODE", "ib"]
      ]
      @TypeByValueMatch = [
        ["BONDING_MASTER", "yes", "bond"],
        ["BRIDGE", "yes", "br"],
        ["WIRELESS", "yes", "wlan"],
        ["TUNNEL", "tap", "tap"],
        ["TUNNEL", "tun", "tun"],
        ["TUNNEL", "sit", "sit"],
        ["TUNNEL", "gre", "gre"],
        ["TUNNEL", "ipip", "ipip"],
        ["PPPMODE", "pppoe", "ppp"],
        ["PPPMODE", "pppoatm", "ppp"],
        ["PPPMODE", "capi-adsl", "ppp"],
        ["PPPMODE", "pptp", "ppp"],
        ["ENCAP", "syncppp", "isdn"],
        ["ENCAP", "rawip", "isdn"]
      ]

      @SensitiveFields = [
        "WIRELESS_WPA_PASSWORD",
        "WIRELESS_WPA_PSK",
        # the unnumbered one should be empty but just in case
        "WIRELESS_KEY",
        "WIRELESS_KEY_0",
        "WIRELESS_KEY_1",
        "WIRELESS_KEY_2",
        "WIRELESS_KEY_3"
      ]
    end

    def IsEmpty(value)
      value.nil? ? true : value.empty?
    end

    # Detects a subtype of Ethernet device type according /sys or /proc content
    #
    # @example
    #   GetEthTypeFromSysfs("eth0") -> "eth"
    #   GetEthTypeFromSysfs("bond0") -> "bon"
    #
    # @param [String] dev interface name
    # @return [String] device type
    def GetEthTypeFromSysfs(dev)
      sys_dir_path = "/sys/class/net/#{dev}"

      if FileUtils.Exists("#{sys_dir_path}/wireless")
        "wlan"
      elsif FileUtils.Exists("#{sys_dir_path}/phy80211")
        "wlan"
      elsif FileUtils.Exists("#{sys_dir_path}/bridge")
        "br"
      elsif FileUtils.Exists("#{sys_dir_path}/bonding")
        "bond"
      elsif FileUtils.Exists("#{sys_dir_path}/tun_flags")
        "tap"
      elsif FileUtils.Exists("/proc/net/vlan/#{dev}")
        "vlan"
      elsif FileUtils.Exists("/sys/devices/virtual/net/#{dev}") && dev =~ /dummy/
        "dummy"
      else
        "eth"
      end
    end

    # Detects a subtype of InfiniBand device type according /sys
    #
    # @example
    #   GetEthTypeFromSysfs("ib0") -> "ib"
    #   GetEthTypeFromSysfs("bond0") -> "bon"
    #   GetEthTypeFromSysfs("ib0.8001") -> "ibchild"
    #
    # @param [String] dev interface name
    # @return [String] device type
    def GetIbTypeFromSysfs(dev)
      sys_dir_path = "/sys/class/net/#{dev}"

      if FileUtils.Exists("#{sys_dir_path}/bonding")
        "bond"
      elsif FileUtils.Exists("#{sys_dir_path}/create_child")
        "ib"
      else
        "ibchild"
      end
    end

    # Determines device type according /sys/class/net/<dev>/type value
    #
    # Firstly, it uses /sys/class/net/<dev>/type for basic decision. Obtained values are translated to
    # device type according <kernel src>/include/uapi/linux/if_arp.h. Sometimes it uses some other checks
    # to specify a "subtype". E.g. in case of "eth" it checks for presence of "wireless" subdir to
    # determine "wlan" device.
    #
    # @param [String] dev interface name
    # @return return device type or nil if nothing known found
    def GetTypeFromSysfs(dev)
      sys_dir_path = Builtins.sformat("/sys/class/net/%1", dev)
      sys_type_path = Builtins.sformat("%1/type", sys_dir_path)

      return nil if IsEmpty(dev) || !FileUtils.Exists(sys_type_path)

      sys_type = Convert.to_string(
        SCR.Read(path(".target.string"), sys_type_path)
      )
      sys_type = if sys_type
        Builtins.regexpsub(sys_type, "(.*)\n", "\\1")
      else
        ""
      end

      sys_type = String.CutBlanks(sys_type)

      type = case sys_type
      when "1"
        GetEthTypeFromSysfs(dev)
      when "32"
        GetIbTypeFromSysfs(dev)
      else
        Ops.get(@TypeBySysfs, sys_type)
      end

      Builtins.y2debug(
        "GetTypeFromSysFs: device='%1', sysfs type='%2', type='%3'",
        dev,
        sys_type,
        type
      )

      return nil if IsEmpty(type)

      type
    end

    # Detects device type according given ifcfg configuration
    #
    # @return device type or nil if type cannot be recognized from ifcfg config
    def GetTypeFromIfcfg(ifcfg)
      ifcfg = deep_copy(ifcfg)
      type = nil

      return nil if IsEmpty(ifcfg)

      Builtins.foreach(@TypeByValueMatch) do |key_type|
        rule_key = Ops.get(key_type, 0, "")
        rule_value = Ops.get(key_type, 1, "")
        rule_type = Ops.get(key_type, 2, "")
        type = rule_type if (ifcfg[rule_key] || "").casecmp?(rule_value)
      end

      Builtins.foreach(@TypeByKeyExistence) do |key_type|
        rule_key = Ops.get(key_type, 0, "")
        rule_type = Ops.get(key_type, 1, "")
        type = rule_type if Ops.get_string(ifcfg, rule_key, "") != ""
      end

      Builtins.foreach(@TypeByKeyValue) do |rule_key|
        rule_type = Ops.get_string(ifcfg, rule_key, "")
        type = rule_type if rule_type != ""
      end

      type
    end

    # Detects device type according its name and ifcfg configuration.
    #
    # @param dev   device name
    # @param ifcfg device's ifcfg configuration
    # @return      device type
    def GetTypeFromIfcfgOrName(dev, ifcfg)
      ifcfg = deep_copy(ifcfg)
      return nil if IsEmpty(dev)

      type = GetTypeFromSysfs(dev)

      type = GetTypeFromIfcfg(ifcfg) if IsEmpty(type)

      # last instance - no record in sysfs, no configuration, device
      # name is not bounded to a type -> use fallbac "eth" as wicked already does
      type = "eth" if type.nil?

      log.debug("GetTypeFromIfcfgOrName: device='#{dev}' type='#{type}'")

      type
    end

    # Detects device type according cached data
    #
    # If cached ifcfg for given device is found it is used as parameter for
    # GetTypeFromIfcfgOrName( dev, ifcfg). Otherwise is device handled as unconfigured
    # and result is equal to GetTypeFromIfcfgOrName( dev, nil)
    #
    # @param dev   device name
    # @return      detected device type
    def GetType(dev)
      type = GetTypeFromIfcfgOrName(dev, nil)

      Builtins.foreach(@Devices) do |_dev_type, confs|
        ifcfg = Ops.get(confs, dev, {})
        type = GetTypeFromIfcfgOrName(dev, ifcfg) if !IsEmpty(ifcfg)
      end

      type
    end

    # Return device type in human readable form :-)
    # @param [String] dev device
    # @return device type
    # @example GetDeviceTypeName(eth-bus-pci-0000:01:07.0) -> "Network Card"
    # @example GetDeviceTypeName(modem0) -> "Modem"
    def GetDeviceTypeName(dev)
      # pppN must be tried before pN, modem before netcard
      if Builtins.regexpmatch(
        dev,
        Ops.add("^", Ops.get(@DeviceRegex, "modem", ""))
      )
        _("Modem")
      elsif Builtins.regexpmatch(
        dev,
        Ops.add("^", Ops.get(@DeviceRegex, "netcard", ""))
      )
        _("Network Card")
      elsif Builtins.regexpmatch(
        dev,
        Ops.add("^", Ops.get(@DeviceRegex, "isdn", ""))
      )
        _("ISDN")
      elsif Builtins.regexpmatch(
        dev,
        Ops.add("^", Ops.get(@DeviceRegex, "dsl", ""))
      )
        _("DSL")
      else
        _("Unknown")
      end
    end

    # Create a device name from its type and number
    # @param [String] typ device type
    # @param [String] num device number
    # @return device name
    # @example device_name("eth", "1") -> "eth1"
    # @example device_name("lo", "") -> "lo"
    def device_name(typ, num)
      if typ.nil? || typ == ""
        Builtins.y2error("wrong type: %1", typ)
        return nil
      end
      if num.nil?
        Builtins.y2error("wrong number: %1", num)
        return nil
      end
      return Builtins.sformat("%1%2", typ, num) if Builtins.regexpmatch(num, "^[0-9]*$")

      Builtins.sformat("%1-%2", typ, num)
    end

    # Extracts device name from alias name
    #
    # alias_name := <device_name>{ALIAS_SEPARATOR}<alias_name>
    def device_name_from_alias(alias_name)
      alias_name.sub(/#{ALIAS_SEPARATOR}.*/, "")
    end

    # Create a alias name from its type and numbers
    # @param [String] typ device type
    # @param [String] num device number
    # @param [String] anum alias number
    # @return alias name
    # @example alias_name("eth", "1", "2") -> "eth1#2"
    def alias_name(typ, num, anum)
      if typ.nil? || typ == ""
        Builtins.y2error("wrong type: %1", typ)
        return nil
      end
      if num.nil? # || num < 0
        Builtins.y2error("wrong number: %1", num)
        return nil
      end
      if anum.nil? || anum == ""
        Builtins.y2error("wrong alias number: %1", anum)
        return nil
      end
      Builtins.sformat("%1#%2", device_name(typ, num), anum)
    end

    # @deprecated Formerly hotpluggable devices required a special ifcfg name
    # @return false
    def IsHotplug(_type)
      false
    end

    # Test whether device is connected (Link:up)
    # The info is taken from sysfs
    # @param [String] dev unique device string
    # @return true if connected
    def IsConnected(dev)
      # Assume all devices are connected in testsuite mode
      return true if Mode.testsuite

      cmd = "/usr/bin/cat /sys/class/net/#{dev.shellescape}/carrier"

      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("Sysfs returned %1", ret)

      Builtins.deletechars(Ops.get_string(ret, "stdout", ""), "\n") == "1"
    end

    # @deprecated hotpluggable devices no longer need a special type
    # Return real type of the device (incl. PCMCIA, USB, ...)
    # @param [String] type basic device type
    # @param [String] hotplug hot plug type
    # @return real type
    # @example RealType("eth", "usb") -> "eth"
    def RealType(type, _hotplug)
      if type == "" || type.nil?
        Builtins.y2error("Wrong type: %1", type)
        return "eth"
      end
      type
    end

    # ---------------------------------------------------------------------------

    # STARTMODE: onboot, on and boot are aliases for auto
    def CanonicalizeStartmode(ifcfg)
      ifcfg = deep_copy(ifcfg)
      canonicalize_startmode = {
        "on"     => "auto",
        "boot"   => "auto",
        "onboot" => "auto"
      }
      startmode = Ops.get_string(ifcfg, "STARTMODE", "")
      Ops.set(
        ifcfg,
        "STARTMODE",
        Ops.get(canonicalize_startmode, startmode, startmode)
      )
      deep_copy(ifcfg)
    end

    #
    # Canonicalize static ip configuration obtained from sysconfig. (suse#46885)
    #
    # Static ip configuration formats supported by sysconfig:
    # 1) IPADDR=10.0.0.1/8
    # 2) IPADDR=10.0.0.1 PREFIXLEN=8
    # 3) IPADDR=10.0.0.1 NETMASK=255.0.0.0
    #
    # Features:
    # - IPADDR (in form <ip>/<prefix>) overrides PREFIXLEN,
    # - NETMASK is used only if prefix length unspecified)
    # - If prefix length and NETMASK are unspecified, 32 is implied.
    #
    # Canonicalize it to:
    # - IPADDR="<ipv4>" PREFIXLEN="<prefix>" NETMASK="<netmask>") in case of IPv4 config
    # E.g. IPADDR=10.0.0.1 PREFIXLEN=8 NETMASK=255.0.0.0
    # - IPADDR="<ipv6>" PREFIXLEN="<prefix>" NETMASK="") in case of IPv6 config
    # E.g. IPADDR=2001:15c0:668e::5 PREFIXLEN=48 NETMASK=""
    #
    # @param ifcfg     a map with netconfig (ifcfg) configuration for a one device
    # @return          a map with IPADDR, NETMASK and PREFIXLEN adjusted if IPADDR is present.
    #                  Returns original ifcfg if IPADDR is not present. In case of error,
    #                  returns nil.
    #
    def CanonicalizeIP(ifcfg)
      ifcfg = deep_copy(ifcfg)
      return nil if ifcfg.nil?

      ipaddr, prefixlen = ifcfg["IPADDR"].to_s.split("/")

      return ifcfg if ipaddr.to_s == "" # DHCP or inconsistent

      prefixlen = ifcfg["PREFIXLEN"].to_s if prefixlen.to_s == ""

      prefixlen = Netmask.ToBits(ifcfg["NETMASK"].to_s).to_s if prefixlen == ""

      # Now we have ipaddr and prefixlen
      # Let's compute the rest
      netmask = IP.Check4(ipaddr) ? Netmask.FromBits(prefixlen.to_i) : ""

      ifcfg["IPADDR"] = ipaddr
      ifcfg["PREFIXLEN"] = prefixlen
      ifcfg["NETMASK"] = netmask

      ifcfg
    end

    # Filters out INTERFACETYPE option from ifcfg config when it is not needed.
    #
    # INTERFACETYPE has big impact on wicked even yast behavior. It was overused
    # by yast in the past. According wicked team it makes sense to use it only
    # in two cases 1) lo device (when it's name is changed - very strongly discouraged)
    # 2) dummy device
    #
    # This function silently modifies user's config files. However, it should make sense
    # because:
    # - INTERFACETYPE is usually not needed
    # - other functions in this module modifies the config as well (see Canonicalize* functions)
    # - using INTERFACETYPE is reported as a warning by wicked (it asks for reporting a bug)
    # - it is often ignored by wicked
    def filter_interfacetype(devmap)
      ret = deep_copy(devmap)
      ret.delete_if { |k, v| k == "INTERFACETYPE" && !["lo", "dummy"].include?(v) }
    end

    # Conceal secret information, such as WEP keys, so that the output
    # can be passed to y2log and bugzilla.
    # @param [Hash{String => Object}] ifcfg one ifcfg
    # @return ifcfg with secret fields masked out
    def ConcealSecrets1(ifcfg)
      ifcfg = deep_copy(ifcfg)
      return nil if ifcfg.nil?

      secret_fields = ifcfg.select { |k, v| @SensitiveFields.include?(k) && v != "" }
      secret_fields.map { |k, _v| ifcfg[k] = "CONCEALED" }

      ifcfg
    end

    # Conceal secret information, such as WEP keys, so that the output
    # can be passed to y2log and bugzilla. (#65741)
    # @param [Hash] devs a two-level map of ifcfgs like Devices
    # @return ifcfgs with secret fields masked out
    def ConcealSecrets(devs)
      devs = deep_copy(devs)
      return nil if devs.nil?

      out = Builtins.mapmap(
        Convert.convert(
          devs,
          from: "map",
          to:   "map <string, map <string, map <string, any>>>"
        )
      ) do |t, tdevs|
        tout = Builtins.mapmap(tdevs) do |id, ifcfg|
          { id => ConcealSecrets1(ifcfg) }
        end
        { t => tout }
      end
      deep_copy(out)
    end

    # Canonicalize IPADDR and STARTMODE of given config
    # and nested _aliases
    #
    # @param [Hash] config a map with netconfig (ifcfg) configuration
    # @return [Hash] ifcfg with canonicalized IP addresses
    def canonicalize_config(config)
      config = deep_copy(config)
      # canonicalize, #46885
      (config["_aliases"] || {}).tap do |aliases|
        aliases.each { |a, c| aliases[a] = CanonicalizeIP(c) }
      end

      config = CanonicalizeIP(config)
      CanonicalizeStartmode(config)
    end

    # Variables which could be suffixed and thus duplicated
    LOCALS = [
      "IPADDR",
      "REMOTE_IPADDR",
      "NETMASK",
      "PREFIXLEN",
      "BROADCAST",
      "SCOPE",
      "LABEL",
      "IP_OPTIONS"
    ].freeze

    # It reads, parses and transforms the given attributes
    # from the given device config path returning a hash
    # with the transformed device config
    #
    # @param [String] pth path of the device config to read from
    # @param [Hash<String, Object>] values new device map
    #
    # @return [Hash{String => Object}] parsed configuration
    def generate_config(pth, values)
      config = {}
      values.each do |val|
        item = SCR.Read(path("#{pth}.#{val}"))
        log.debug("item=#{item}")
        next if item.nil?

        # No underscore '_' -> global
        # Also temporarily standard globals
        if !val.include?("_") || LOCALS.include?(val)
          config[val] = item
          next
        end

        # Try to strip _suffix
        # @example "IP_OPTIONS_1".rpartition("_") => ["IP_OPTIONS", "_", "1"]
        v, _j, s = val.rpartition("_")
        log.info("#{val}:#{v}:#{s}")
        # Global
        if !LOCALS.include?(v)
          config[val] = item
        else
          config["_aliases"] ||= {}
          config["_aliases"][s] ||= {}
          config["_aliases"][s][v] = item
        end
      end
      log.info("config=#{ConcealSecrets1(config)}")
      config = canonicalize_config(config)
      filter_interfacetype(config)
    end

    # Adapts the interface configuration used during many year for enslaved
    # interfaces (IPADDR == 0.0.0.0 and BOOTPROTO == 'static').
    #
    # Sets the BOOTPROTO as none, empties the IPADDR, and also empties the
    # NETMASK and the PREFIXLEN if exist.
    def adapt_old_config!
      @Devices.each do |devtype, devices|
        devices.each do |device, config|
          bootproto = config["BOOTPROTO"] || "static"
          next unless bootproto == "static" && config["IPADDR"] == "0.0.0.0"

          config["BOOTPROTO"] = "none"
          config["IPADDR"]    = ""
          config["NETMASK"]   = "" if config.key? "NETMASK"
          config["PREFIXLEN"] = "" if config.key? "PREFIXLEN"

          @Devices[devtype][device] = config
        end
      end

      @Devices
    end

    # The device is added to @Devices[devtype] hash using the device name as key
    # and the ifconfg hash as value
    #
    # @param [String] device name
    # @param [Hash] ifcfg a map with netconfig (ifcfg) configuration
    def add_device(device, ifcfg)
      # if possible use dev type as available in /sys otherwise use ifcfg config
      # as a fallback for device type detection
      devtype = GetTypeFromIfcfgOrName(device, ifcfg)
      @Devices[devtype] ||= {}
      @Devices[devtype][device] = ifcfg
    end

    # Read devices from files and cache it
    # @return true if sucess
    def Read
      return true if @initialized == true

      @Devices = {}

      # preparation
      devices = get_devices(ignore_confs_regex)

      # Read devices
      devices.each do |device|
        pth = ".network.value.\"#{device}\""
        log.debug("pth=#{pth}")

        values = SCR.Dir(path(pth))
        log.debug("values=#{values}")

        config = generate_config(pth, values)

        add_device(device, config)
      end
      log.debug("Devices=#{@Devices}")

      @OriginalDevices = deep_copy(@Devices)
      @initialized = true
    end

    # re-read all settings again from system
    # for creating new proposal from scratch (#170558)
    def CleanCacheRead
      @initialized = false
      Read()
    end

    # Returns a hash with configuration for particular device
    #
    # Hash map is direct maping of sysconfig file into hash.
    # Keys are sysconfig options (e.g. { 'IPADDR' => '1.1.1.1' }
    #
    # @param [String] name is device name as provided by the
    #                 system (e.g. eth0)
    # @return [Hash] device configuration or nil in case of error
    def devmap(name)
      Devices().fetch(GetType(name), {})[name]
    end

    # Returns all the devices which device name matchs given devregex
    #
    # @param [Array] devices of Devices
    # @param [String] devregex regex to filter by
    # @return [Array] of Devices that match the given regex
    def Filter(devices, devregex)
      devices = deep_copy(devices)
      return devices if devices.nil? || devregex.nil? || devregex == ""

      regex = "^(#{@DeviceRegex[devregex] || devregex})[0-9]*$"
      log.debug("regex=#{regex}")
      devices.select! { |f, _d| f =~ /#{regex}/ }
      log.debug("devices=#{devices}")
      devices
    end

    # Used in BuildSummary, BuildOverview
    def FilterDevices(devregex)
      Filter(@Devices, devregex)
    end

    # Returns all the devices that does not match the given devregex
    #
    # @param [Array] devices of Devices
    # @param [String] devregex regex to filter by
    # @return [Array] of Devices that match the given regex
    def FilterNOT(devices, devregex)
      return {} if devices.nil? || devregex.nil? || devregex == ""

      devices = deep_copy(devices)

      regex = "^(#{@DeviceRegex[devregex] || devregex})[0-9]*$"

      log.debug("regex=#{regex}")
      devices.reject! { |f, _d| f =~ /#{regex}/ }

      log.debug("devices=#{devices}")
      devices
    end

    def Write(devregex)
      log.info("Writing configuration")
      log.debug("Devices=#{@Devices}")
      log.debug("Deleted=#{@Deleted}")

      devs = Filter(@Devices, devregex)
      original_devs = Filter(@OriginalDevices, devregex)
      log.info("OriginalDevs=#{ConcealSecrets(original_devs)}")
      log.info("Devs=#{ConcealSecrets(devs)}")

      # Check for changes
      if devs == original_devs
        log.info("No changes to #{devregex} devices -> nothing to write")
        return true
      end

      # remove deleted devices
      log.info("Deleted=#{@Deleted}")
      Builtins.foreach(@Deleted) do |d|
        # delete config file
        p = Builtins.add(path(".network.section"), d)
        log.debug("deleting: #{p}")
        SCR.Write(p, nil)
      end
      @Deleted = []

      # write all devices
      Builtins.maplist(
        Convert.convert(
          devs,
          from: "map",
          to:   "map <string, map <string, map <string, any>>>"
        )
      ) do |typ, devsmap|
        Builtins.maplist(devsmap) do |config, devmap|
          next if devmap == Ops.get_map(original_devs, [typ, config], {})

          # write sysconfig
          p = Ops.add(Ops.add(".network.value.\"", config), "\".")
          if Ops.greater_than(
            Builtins.size(Ops.get_string(devmap, "IPADDR", "")),
            0
          ) &&
              Builtins.find(Ops.get_string(devmap, "IPADDR", ""), "/") == -1
            if Ops.greater_than(
              Builtins.size(Ops.get_string(devmap, "IPADDR", "")),
              0
            ) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(devmap, "NETMASK", "")),
                  0
                )
              Ops.set(
                devmap,
                "IPADDR",
                Builtins.sformat(
                  "%1/%2",
                  Ops.get_string(devmap, "IPADDR", ""),
                  Netmask.ToBits(Ops.get_string(devmap, "NETMASK", ""))
                )
              )
              devmap = Builtins.remove(devmap, "NETMASK")
              # TODO : delete NETMASK from config file
            elsif Ops.greater_than(
              Builtins.size(Ops.get_string(devmap, "IPADDR", "")),
              0
            ) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(devmap, "PREFIXLEN", "")),
                  0
                )
              Ops.set(
                devmap,
                "IPADDR",
                Builtins.sformat(
                  "%1/%2",
                  Ops.get_string(devmap, "IPADDR", ""),
                  Ops.get_string(devmap, "PREFIXLEN", "")
                )
              )
              devmap = Builtins.remove(devmap, "PREFIXLEN")
              # TODO : delete PREFIXLEN from config file
            end
          end
          # write all keys to config
          Builtins.maplist(
            Convert.convert(
              Map.Keys(devmap),
              from: "list",
              to:   "list <string>"
            )
          ) do |k|
            # Write aliases
            if k == "_aliases"
              Builtins.maplist(Ops.get_map(devmap, k, {})) do |anum, amap|
                # Normally defaulting the label would be done
                # when creating the map, not here when
                # writing, but we create it in 2 ways so it's
                # better here. Actually it does not work because
                # the edit dialog nukes LABEL :-(
                if Ops.greater_than(Builtins.size(Ops.get(amap, "IPADDR", "")), 0) &&
                    Ops.greater_than(
                      Builtins.size(Ops.get(amap, "NETMASK", "")),
                      0
                    )
                  Ops.set(
                    amap,
                    "IPADDR",
                    Builtins.sformat(
                      "%1/%2",
                      Ops.get(amap, "IPADDR", ""),
                      Netmask.ToBits(Ops.get(amap, "NETMASK", ""))
                    )
                  )
                  amap = Builtins.remove(amap, "NETMASK")
                  # TODO : delete NETMASK from config file
                elsif Ops.greater_than(
                  Builtins.size(Ops.get(amap, "IPADDR", "")),
                  0
                ) &&
                    Ops.greater_than(
                      Builtins.size(Ops.get(amap, "PREFIXLEN", "")),
                      0
                    )
                  Ops.set(
                    amap,
                    "IPADDR",
                    Builtins.sformat(
                      "%1/%2",
                      Ops.get(amap, "IPADDR", ""),
                      Ops.get(amap, "PREFIXLEN", "")
                    )
                  )
                  amap = Builtins.remove(amap, "PREFIXLEN")
                  # TODO : delete PREFIXLEN from config file
                end
                Builtins.maplist(amap) do |ak, av|
                  akk = Ops.add(Ops.add(ak, "_"), anum)
                  SCR.Write(Builtins.topath(Ops.add(p, akk)), av) #          seen_label = seen_label || ak == "LABEL";
                end
              end
            else
              # Write regular keys
              SCR.Write(
                Builtins.topath(Ops.add(p, k)),
                Ops.get_string(devmap, k, "")
              )
            end
          end

          # 0600 if contains encryption key (#24842)
          has_key = @SensitiveFields.any? { |k| devmap[k] && !devmap[k].empty? }
          if has_key
            log.debug("Permission change: #{config}")
            SCR.Write(
              Builtins.add(path(".network.section_private"), config),
              true
            )
          end
          @OriginalDevices = {} if @OriginalDevices.nil?
          Ops.set(@OriginalDevices, typ, {}) if Ops.get(@OriginalDevices, typ).nil?
          Ops.set(
            @OriginalDevices,
            [typ, config],
            Ops.get(@Devices, [typ, config], {})
          )
        end
      end

      # Finish him
      SCR.Write(path(".network"), nil)

      true
    end

    # Import data
    #
    # All devices which confirms to <devregex> are silently removed from Devices
    # and replaced by those supplied by <devices>.
    #
    # @param [String] devregex filter for devices
    # @param [Array] devices devices to replace filtered ones
    # @return true on success
    def Import(devregex, devices)
      devices = deep_copy(devices)
      devs = FilterNOT(@Devices, devregex)
      Builtins.y2debug("Devs=%1", devs)

      devices = Builtins.mapmap(devices) do |typ, devsmap|
        {
          typ => Builtins.mapmap(
            Convert.convert(
              devsmap,
              from: "map",
              to:   "map <string, map <string, any>>"
            )
          ) do |num, config|
            config = CanonicalizeIP(config)
            config = CanonicalizeStartmode(config)
            { num => config }
          end
        }
      end

      @Devices = Convert.convert(
        Builtins.union(devs, devices),
        from: "map",
        to:   "map <string, map <string, map <string, any>>>"
      )

      @initialized = if devices.nil? || devices == {}
        # devices == $[] is used in lan_auto "Reset" as a way how to
        # rollback changes imported from AY
        false
      else
        true
      end

      Builtins.y2milestone(
        "NetworkInterfaces::Import - done, cache content: %1",
        @Devices
      )

      true
    end

    # Return supported network device types (for type netcard)
    # for this hardware
    def GetDeviceTypes
      # common linux device types available on all architectures
      common_dev_types = ["eth", "vlan", "br", "tun", "tap", "bond"]

      # s390 specific device types
      s390_dev_types = ["hsi", "ctc", "ficon", "iucv", "qeth", "lcs"]

      # device types which cannot be present on s390 arch
      s390_unknown_dev_types = [
        "dummy",
        "wlan",
        "ib"
      ]

      dev_types = common_dev_types + (Arch.s390 ? s390_dev_types : s390_unknown_dev_types)

      Builtins.foreach(dev_types) do |device|
        if !Builtins.contains(
          Builtins.splitstring(Ops.get(@DeviceRegex, "netcard", ""), "|"),
          device
        )
          Builtins.y2error(
            "%1 is not contained in DeviceRegex[\"netcard\"]",
            device
          )
        end
      end

      deep_copy(dev_types)
    end

    # Return textual device type
    # @param [String] type device type
    # @param [String] longdescr description type
    # @return textual form of device type
    # @example
    #   GetDevTypeDescription("eth", false) -> "Ethernet"
    # @example
    #   GetDevTypeDescription("eth", true)  -> "Ethernet Network Card"
    def GetDevTypeDescription(type, longdescr)
      if Builtins.issubstring(type, "#")
        # Device type label
        # This is what used to be Virtual Interface (eth0:1).
        # In our data model, additional addresses for an interface
        # are represented as its sub-interfaces.
        # And also we frequently confuse "device" and "interface"
        # :-(
        return _("Additional Address")
      end

      device_types = {
        # Device type label
        "atm"   => [
          _("ATM"),
          _("Asynchronous Transfer Mode (ATM)")
        ],
        # Device type label
        "bond"  => [_("Bond"), _("Bond Network")],
        # Device type label
        "ci"    => [
          _("CLAW"),
          _("Common Link Access for Workstation (CLAW)")
        ],
        # Device type label
        "ctc"   => [
          _("CTC"),
          _("Channel to Channel Interface (CTC)")
        ],
        # Device type label
        "dsl"   => [_("DSL"), _("DSL Connection")],
        # Device type label
        "dummy" => [_("Dummy"), _("Dummy Network Device")],
        # Device type label
        "eth"   => [
          _("Ethernet"),
          _("Ethernet Network Card")
        ],
        # Device type label
        "ficon" => [
          _("FICON"),
          _("Fiberchannel System Connector (FICON)")
        ],
        # Device type label
        "hippi" => [
          _("HIPPI"),
          _("HIgh Performance Parallel Interface (HIPPI)")
        ],
        # Device type label
        "hsi"   => [
          _("Hipersockets"),
          _("Hipersockets Interface (HSI)")
        ],
        # Device type label
        "ippp"  => [_("ISDN"), _("ISDN Connection")],
        # Device type label
        "irlan" => [_("IrDA"), _("Infrared Network Device")],
        # Device type label
        "irda"  => [_("IrDA"), _("Infrared Device")],
        # Device type label
        "isdn"  => [_("ISDN"), _("ISDN Connection")],
        # Device type label
        "lcs"   => [_("OSA LCS"), _("OSA LCS Network Card")],
        # Device type label
        "lo"    => [_("Loopback"), _("Loopback Device")],
        # Device type label
        "modem" => [_("Modem"), _("Modem")],
        # Device type label
        "net"   => [_("ISDN"), _("ISDN Connection")],
        # Device type label
        "plip"  => [
          _("Parallel Line"),
          _("Parallel Line Connection")
        ],
        # Device type label
        "ppp"   => [_("Modem"), _("Modem")],
        # Device type label
        "qeth"  => [
          _("QETH"),
          _("OSA-Express or QDIO Device (QETH)")
        ],
        # Device type label
        "sit"   => [
          _("IPv6-in-IPv4"),
          _("IPv6-in-IPv4 Encapsulation Device")
        ],
        # Device type label
        "slip"  => [
          _("Serial Line"),
          _("Serial Line Connection")
        ],
        # Device type label
        "vmnet" => [_("VMWare"), _("VMWare Network Device")],
        # Device type label
        "wlan"  => [
          _("Wireless"),
          _("Wireless Network Card")
        ],
        # Device type label
        "vlan"  => [_("VLAN"), _("Virtual LAN")],
        # Device type label
        "br"    => [_("Bridge"), _("Network Bridge")],
        # Device type label
        "tun"   => [_("TUN"), _("Network TUNnel")],
        # Device type label
        "tap"   => [_("TAP"), _("Network TAP")],
        # Device type label
        "ib"    => [_("InfiniBand"), _("InfiniBand Device")]
      }

      if Builtins.haskey(device_types, type)
        return Ops.get_string(
          device_types,
          [type, (longdescr == true) ? 1 : 0],
          ""
        )
      end

      type1 = String.FirstChunk(type, "-")
      if Builtins.haskey(device_types, type1)
        return Ops.get_string(
          device_types,
          [type1, (longdescr == true) ? 1 : 0],
          ""
        )
      end

      Builtins.y2error("Unknown type: %1", type)
      type
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export(devregex)
      devs = Filter(@Devices, devregex)
      log.debug("Devs=#{devs}")
      devs
    end

    # Were the devices changed?
    # @return true if modified
    def Modified(devregex)
      devs = Filter(@Devices, devregex)
      original_devs = Filter(@OriginalDevices, devregex)
      log.debug("OriginalDevs=#{original_devs}")
      log.debug("Devs=#{devs}")
      devs == original_devs
    end

    # Check presence of the device (alias)
    # @param [String] dev device identifier
    # @return true if device is present
    def Check(dev)
      Builtins.y2debug("Check(%1)", dev)
      typ = GetType(dev)
      return false if !Builtins.haskey(@Devices, typ)

      devsmap = Ops.get(@Devices, typ, {})
      return false if !Builtins.haskey(devsmap, dev)

      Builtins.y2debug("Check passed")
      true
    end

    # Select the given device
    # @param [String] name device to select ("" for new device, default values)
    # @return true if success
    def Select(name)
      @Name = ""
      @Current = {}

      Builtins.y2debug("name=%1", name)
      if name != "" && !Check(name)
        Builtins.y2error("No such device: %1", name)
        return false
      end

      @Name = name
      t = GetType(@Name)
      @Current = Ops.get(@Devices, [t, @Name], {})

      Builtins.y2debug("Name=%1", @Name)
      Builtins.y2debug("Current=%1", @Current)

      true
    end

    # Add a new device
    # @return true if success
    def Add
      @operation = nil
      return false if Select("") != true

      @operation = :add
      true
    end

    # Edit the given device
    # @param [String] name device to edit
    # @return true if success
    def Edit(name)
      @operation = nil
      return false if Select(name) != true

      @operation = :edit
      true
    end

    # Delete the given device
    # @param [String] name device to delete
    # @return true if success
    def Delete(name)
      @operation = nil
      return false if Select(name) != true

      @operation = :delete
      true
    end

    # Update Devices map
    # @param [String] name device identifier
    # @param [Hash<String, Object>] newdev new device map
    # @param [true, false] check if check if device already exists
    # @return true if success
    def Change2(name, newdev, check)
      newdev = deep_copy(newdev)
      Builtins.y2debug("Change(%1,%2,%3)", name, newdev, check)
      Builtins.y2debug("Devices=%1", @Devices)
      if Check(name) && check
        Builtins.y2error("Device already present: %1", name)
        return false
      end

      t = if !IsEmpty(newdev)
        GetTypeFromIfcfgOrName(name, newdev)
      else
        GetType(name)
      end

      if name == @Name
        int_type = Ops.get_string(@Current, "INTERFACETYPE", "")

        t = int_type if Ops.greater_than(Builtins.size(int_type), 0)
      end
      Builtins.y2debug("ChangeDevice(%1)", name)

      # newdev is already a deep_copy created above
      @Devices[t] = @Devices.fetch(t, {}).merge(name => newdev)

      Builtins.y2debug("Devices=%1", @Devices)
      true
    end

    def Delete2(name)
      if !Check(name)
        Builtins.y2error("Device not found: %1", name)
        return false
      end

      t = GetType(name)
      devsmap = Ops.get(@Devices, t, {})

      devsmap = Builtins.remove(devsmap, name)

      Ops.set(@Devices, t, devsmap)

      # Originally this avoided errors in the log when deleting an
      # interface that was not present at Read (had no ifcfg file).
      # #115448: OriginalDevices is not updated after Write so
      # returning to the network proposal and deleting a card would not work.
      Builtins.y2milestone("Deleting file: #{name}")
      @Deleted << name
      true
    end

    # Add the alias to the list of deleted items.
    # Called when exiting from the aliases-of-device dialog.
    # #48191
    def DeleteAlias(device, aid)
      alias_ = Builtins.sformat("%1#%2", device, aid)
      Builtins.y2milestone("Deleting alias: %1", alias_)
      @Deleted << alias_
      true
    end

    def Commit
      Builtins.y2debug("Name=%1", @Name)
      Builtins.y2debug("Current=%1", @Current)
      Builtins.y2debug("Devices=%1", @Devices)
      Builtins.y2debug("Deleted=%1", @Deleted)
      Builtins.y2debug("operation=%1", @operation)

      if @operation == :add || @operation == :edit
        Change2(@Name, @Current, @operation == :add)
      elsif @operation == :delete
        Delete2(@Name)
      else
        Builtins.y2error("Unknown operation: %1 (%2)", @operation, @Name)
        return false
      end

      Builtins.y2debug("Devices=%1", @Devices)
      Builtins.y2debug("Deleted=%1", @Deleted)

      @Name = ""
      @Current = {}
      @operation = nil

      true
    end

    def GetValue(name, key)
      return nil if !Select(name)

      Ops.get_string(@Current, key, "")
    end

    def SetValue(name, key, value)
      return nil unless Edit(name)
      return false if key.nil? || key == "" || value.nil?

      @Current[key] = value

      Commit()
    end

    # get IP addres + additional IP addresses
    # @param [String] device identifier for network interface
    # @return [Array] of IP addresses of selected interface
    def GetIP(device)
      Select(device)
      ips = [GetValue(device, "IPADDR")]
      Builtins.foreach(Ops.get_map(@Current, "_aliases", {})) do |_key, value|
        ips = Builtins.add(ips, Ops.get_string(value, "IPADDR", ""))
      end
      deep_copy(ips)
    end

    # Locate devices which attributes match given key and value
    #
    # @param [String] key device key
    # @param [String] val device value
    # @return [Array] of devices with key=val
    def Locate(key, val)
      ret = []

      @Devices.values.each do |devsmap|
        devsmap.each do |device, conf|
          ret << device if conf[key] == val
        end
      end

      ret
    end

    # @deprecated No longer needed
    # @return true
    def CleanHotplugSymlink
      true
    end

    # Get devices of the given type
    # @param [String] devregex devices type ("" for all)
    # @return [Array] of found devices
    def List(devregex)
      ret = []
      if devregex == "" || devregex.nil?
        Builtins.maplist(@Devices) do |_t, d|
          Builtins.maplist(
            Convert.convert(
              Map.Keys(d),
              from: "list",
              to:   "list <string>"
            )
          ) { |device| Ops.set(ret, Builtins.size(ret), device) }
        end
      else
        # it's a regex for type, not the whole name
        regex = Ops.add(
          Ops.add("^(", Ops.get(@DeviceRegex, devregex, devregex)),
          ")$"
        )
        Builtins.maplist(@Devices) do |t, d|
          if Builtins.regexpmatch(t, regex)
            Builtins.maplist(
              Convert.convert(
                Map.Keys(d),
                from: "list",
                to:   "list <string>"
              )
            ) { |device| Ops.set(ret, Builtins.size(ret), device) }
          end
        end
      end
      ret = Builtins.filter(ret) do |row|
        next true if !row.nil?

        Builtins.y2error("Filtering out : %1", row)
        false
      end
      Builtins.y2debug("List(%1) = %2", devregex, ret)
      deep_copy(ret)
    end

    # Find the fastest available device
    def Fastest
      ret = ""
      devices = List("")

      # Find the fastest device
      Builtins.foreach(@FastestTypes) do |_num, type|
        Builtins.foreach(devices) do |dev|
          if ret == "" &&
              Builtins.regexpmatch(
                dev,
                Ops.add(Ops.add("^", Ops.get(@DeviceRegex, type, "")), "[0-9]*$")
              ) &&
              IsConnected(dev)
            ret = dev
          end
        end
      end

      Builtins.y2milestone("ret=%1", ret)
      ret
    end

    def FastestType(name)
      ret = ""
      Builtins.maplist(@FastestTypes) do |_num, type|
        regex = Ops.get(@DeviceRegex, type, "")
        if ret == "" &&
            Builtins.regexpmatch(name, Ops.add(Ops.add("^", regex), "[0-9]*$"))
          ret = type
        end
      end

      ret
    end

    # #46803: forbid "/" (filename), maybe also "-" (separator) "_" (escape)
    def ValidCharsIfcfg
      String.ValidCharsFilename
    end

  private

    # Device configuration files are matched against this regexp
    #
    # The regexp defines files which should not be parsed (e.g. ifcfg-eth0.bak)
    #
    # It is usually usefull to ignore files which various editors
    # or other tools or daemons (e.g. firewalld)
    # create as a backup (e.g. ifcfg-eth0~), also users sometime
    # creates a backup when editing files from commandline
    # (typically use extension .bak or .old)
    #
    # Moreover configuration filenames that contain the following
    # blacklisted extensions, will be ignored by wicked:
    # ~ .old .bak .orig .scpmbackup .rpmnew .rpmsave .rpmorig
    #
    # For details see bnc#1073727
    #
    # @return [Regexp] regexp describing ignored configurations
    def ignore_confs_regex
      /(\.bak|\.orig|\.rpmnew|\.rpmorig|\.rpmsave|-range|~|\.old|\.scpmbackup)$/
    end

    # Get current sysconfig configured interfaces
    #
    # @param devregex [Regexp] regexp to filter by
    # @return [Array<String>] of ifcfg names
    def get_devices(devregex)
      devices = SCR.Dir(path(".network.section")) || []

      devices.reject! { |file| file =~ devregex } unless devregex.nil?
      devices.delete_if(&:empty?)

      log.debug "devices=#{devices}"
      devices
    end

    publish variable: :Name, type: "string"
    publish variable: :Current, type: "map <string, any>"
    publish variable: :CardRegex, type: "map <string, string>"
    publish function: :GetTypeFromIfcfg, type: "string (map <string, any>)"
    publish function: :GetType, type: "string (string)"
    publish function: :GetDeviceTypeName, type: "string (string)"
    publish function: :IsHotplug, type: "boolean (string)"
    publish function: :IsConnected, type: "boolean (string)"
    publish function: :RealType, type: "string (string, string)"
    publish function: :CanonicalizeIP, type: "map <string, any> (map <string, any>)"
    publish function: :ConcealSecrets1, type: "map (map <string, any>)"
    publish function: :ConcealSecrets, type: "map (map)"
    publish function: :Read, type: "boolean ()"
    publish function: :CleanCacheRead, type: "boolean ()"
    publish function: :FilterDevices, type: "map <string, map> (string)"
    publish function: :Write, type: "boolean (string)"
    publish function: :Import, type: "boolean (string, map <string, map>)"
    publish function: :GetDeviceTypes, type: "list <string> ()"
    publish function: :GetDevTypeDescription, type: "string (string, boolean)"
    publish function: :Export, type: "map <string, map> (string)"
    publish function: :Check, type: "boolean (string)"
    publish function: :Select, type: "boolean (string)"
    publish function: :Add, type: "boolean ()"
    publish function: :Edit, type: "boolean (string)"
    publish function: :Delete, type: "boolean (string)"
    publish function: :Delete2, type: "boolean (string)"
    publish function: :DeleteAlias, type: "boolean (string, string)"
    publish function: :Commit, type: "boolean ()"
    publish function: :GetValue, type: "string (string, string)"
    publish function: :SetValue, type: "boolean (string, string, string)"
    publish function: :GetIP, type: "list <string> (string)"
    publish function: :Locate, type: "list <string> (string, string)"
    publish function: :CleanHotplugSymlink, type: "boolean ()"
    publish function: :List, type: "list <string> (string)"
    publish function: :Fastest, type: "string ()"
    publish function: :FastestType, type: "string (string)"
    publish function: :ValidCharsIfcfg, type: "string ()"
  end

  NetworkInterfaces = NetworkInterfacesClass.new
  NetworkInterfaces.main
end
