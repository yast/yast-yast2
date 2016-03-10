# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2014 Novell, Inc.
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
#
# File:	modules/SuSEFirewallServices.rb
# Package:	Firewall Services, Ports Aliases.
# Summary:	Definition of Supported Firewall Services and Port Aliases.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Global Definition of Firewall Services
# Defined using TCP, UDP and RPC ports and IP protocols and Broadcast UDP
# ports. Results are cached, so repeating requests are answered faster.

require "yast"

module Yast
  class SuSEFirewalServiceNotFound < StandardError
    def initialize(message)
      super message
    end
  end

  class SuSEFirewallServicesClass < Module
    include Yast::Logger
    Yast.import "SuSEFirewall"

    # Function returns the map of supported (known) services.
    #
    # @return [Hash{String => String}] supported services
    #
    # **Structure:**
    #
    #     { service_id => localized_service_name }
    #     {
    #         "service:dns-server" => "DNS Server",
    #         "service:vnc" => "Remote Administration",
    #     }
    def GetSupportedServices
      supported_services = {}
      all_services.each do |service_id, service_definition|
        # TRANSLATORS: Name of unknown service. %1 is a requested service id like nfs-server
        supported_services[service_id] = service_definition["name"] || Builtins.sformat(_("Unknown service '%1'"), service_id)
      end
      supported_services
    end

    # Returns all known services loaded from disk on-the-fly
    # @api private
    def all_services
      ReadServicesDefinedByRPMPackages() if @services.nil?
      @services
    end

    # Create appropriate firewall services class based on factors such as which
    # backend is selected by user or running on the system.
    #
    # @note If the backend_sym parameter is :fwd (ie, FirewallD is the desired
    # @note firewall backend), then the method will also start the FirewallD service.
    #
    # @param backend_sym [Symbol] if not nil, explicitely select :sf2 or :fwd
    # @return SuSEFirewall2ServicesClass or SuSEfirewalldServicesClass instance
    def self.create(backend_sym = nil)
      # If backend is specificed, go ahead and create an instance. Otherwise, try
      # to detect which backend is enabled and create the appropriate instance.
      case backend_sym
      when :sf2
        SuSEFirewall2ServicesClass.new
      when :fwd
        # We need to start the backend first
        if !SuSEFirewall.IsStarted()
          log.info "Starting the FirewallD service"
          SuSEFirewall.StartServices()
        end
        SuSEFirewalldServicesClass.new
      when nil
        # Instantiate one based on the running backend
        if SuSEFirewall.is_a?(SuSEFirewall2Class)
          SuSEFirewall2ServicesClass.new
        else
          SuSEFirewalldServicesClass.new
        end
      else
        raise "Invalid symbol for firewall backend #{backend_sym.inspect}"
      end
    end
  end

  class SuSEFirewall2ServicesClass < SuSEFirewallServicesClass
    include Yast::Logger

    # this is how services defined by package are distinguished
    DEFINED_BY_PKG_PREFIX = "service:"

    SERVICES_DIR = "/etc/sysconfig/SuSEfirewall2.d/services/"

    # please, check it with configuration in refresh-srv-def-by-pkgs-trans.sh script
    SERVICES_TEXTDOMAIN = "firewall-services"

    DEFAULT_SERVICE = {
      "tcp_ports"       => [],
      "udp_ports"       => [],
      "rpc_ports"       => [],
      "ip_protocols"    => [],
      "broadcast_ports" => [],
      "name"            => "",
      "description"     => ""
    }

    READ_ONLY_SERVICE_FEATURES = ["name", "description"]

    IGNORED_SERVICES = ["TEMPLATE", "..", "."]

    TEMPLATE_SERVICE_NAME = "template service"
    TEMPLATE_SERVICE_DESCRIPTION = "opens ports for foo in order to allow bar"

    def main
      textdomain "base"

      Yast.import "FileUtils"

      #
      # IF YOU NEED TO ADD ANOTHER SERVICE, CREATE THE SERVICE DEFINITION
      # IN A FILE AND ADD IT TO THE PACKAGE TO WHICH IT BELONGS.
      # USE /etc/sysconfig/SuSEfirewall2.d/services/TEMPLATE FOR THAT.
      #
      # MORE INFORMATION IN FEATURE #300687: Ports for SuSEfirewall added via packages.
      # ANOTHER REFERENCE: Bugzilla #246911.
      #
      # See also http://kobliha-suse.blogspot.cz/2008/06/firewall-services-defined-by-packages.html
      #
      #
      # Names assigned to Port and Protocol numbers can be found
      # here:
      #
      # http://www.iana.org/assignments/protocol-numbers
      # http://www.iana.org/assignments/port-numbers
      #
      # Format of SERVICES
      #
      #   "service-id" : $[
      #     "name"            : _("Service Name"),
      #     "tcp_ports"       : list <tcp_ports>,
      #     "udp_ports"       : list <udp_ports>,
      #     "rpc_ports"       : list <rpc_ports>,
      #     "ip_protocols"    : list <ip_protocols>,
      #     "broadcast_ports" : list <broadcast_ports>,
      #   ],
      #
      @services = nil

      # firewall needs restarting
      @sfws_modified = false

      @known_services_features = {
        "TCP"       => "tcp_ports",
        "UDP"       => "udp_ports",
        "RPC"       => "rpc_ports",
        "IP"        => "ip_protocols",
        "BROADCAST" => "broadcast_ports"
      }

      @known_metadata = { "Name" => "name", "Description" => "description" }

      # Services definitions for conversion to the new ones.
      @OLD_SERVICES = {
        "http"         => {
          "tcp_ports"  => ["http"],
          "convert_to" => ["service:apache2", "service:lighttpd"]
        },
        "https"        => {
          "tcp_ports"  => ["https"],
          "convert_to" => ["service:apache2-ssl", "service:lighttpd-ssl"]
        },
        "smtp"         => { "tcp_ports" => ["smtp"], "convert_to" => [] },
        "pop3"         => { "tcp_ports" => ["pop3"], "convert_to" => [] },
        "pop3s"        => { "tcp_ports" => ["pop3s"], "convert_to" => [] },
        "imap"         => {
          "tcp_ports"  => ["imap"],
          "convert_to" => ["service:courier-imapd"]
        },
        "imaps"        => {
          "tcp_ports"  => ["imaps"],
          "convert_to" => ["service:courier-imap-ssl"]
        },
        "samba-server" => {
          "tcp_ports"       => ["netbios-ssn", "microsoft-ds"],
          # TCP: 139, 445
          "udp_ports"       => ["netbios-ns", "netbios-dgm"],
          # UDP: 137, 138
          "broadcast_ports" => ["netbios-ns", "netbios-dgm"],
          # UDP: 137, 138
          "convert_to"      => []
        },
        "ssh"          => {
          "tcp_ports"  => ["ssh"],
          "convert_to" => ["service:sshd"]
        },
        "rsync"        => { "tcp_ports" => ["rsync"], "convert_to" => [] },
        "dhcp-server"  => {
          "udp_ports"       => ["bootps"],
          "broadcast_ports" => ["bootps"],
          "convert_to"      => ["service:dhcp-server"]
        },
        "dhcp-client"  => { "udp_ports" => ["bootpc"], "convert_to" => [] },
        "dns-server"   => {
          "tcp_ports"  => ["domain"],
          "udp_ports"  => ["domain"],
          "convert_to" => ["service:bind"]
        },
        "nfs-client"   => {
          "rpc_ports"  => ["portmap", "status", "nlockmgr"],
          "convert_to" => ["service:nfs-client"]
        },
        "nfs-server"   => {
          "rpc_ports"  => [
            "portmap",
            "status",
            "nlockmgr",
            "mountd",
            "nfs",
            "nfs_acl"
          ],
          "convert_to" => []
        },
        "nis-client"   => {
          "rpc_ports"  => ["portmap", "ypbind"],
          "convert_to" => ["service:ypserv"]
        },
        "nis-server"   => {
          "rpc_ports"  => [
            "portmap",
            "ypserv",
            "fypxfrd",
            "ypbind",
            "yppasswdd"
          ],
          "convert_to" => []
        },
        # Default SUSE installation
        "vnc"          => {
          "tcp_ports"  => ["5801", "5901"],
          "convert_to" => []
        },
        "tftp"         => { "udp_ports" => ["tftp"], "convert_to" => [] },
        # Internet Printing Protocol as a Server
        "ipp-tcp"      => {
          "tcp_ports"  => ["ipp"],
          "convert_to" => []
        },
        # Internet Printing Protocol as a Client
        # IPP Client needs to listen for broadcast messages
        "ipp-udp"      => {
          "udp_ports"       => ["ipp"],
          "broadcast_ports" => ["ipp"],
          "convert_to"      => []
        },
        "ntp-server"   => {
          "udp_ports"       => ["ntp"],
          "broadcast_ports" => ["ntp"],
          "convert_to"      => ["service:ntp"]
        },
        "ldap"         => {
          "tcp_ports"  => ["ldap"],
          "convert_to" => ["service:openldap"]
        },
        "ldaps"        => { "tcp_ports" => ["ldaps"], "convert_to" => [] },
        "ipsec"        => {
          "udp_ports"    => ["isakmp", "ipsec-nat-t"],
          "ip_protocols" => ["esp"],
          "convert_to"   => []
        },
        "slp-daemon"   => {
          "tcp_ports"       => ["svrloc"],
          "udp_ports"       => ["svrloc"],
          "broadcast_ports" => ["svrloc"],
          "convert_to"      => []
        },
        # See bug #118200 for more information
        "xdmcp"        => {
          "tcp_ports"       => ["xdmcp"],
          "udp_ports"       => ["xdmcp"],
          "broadcast_ports" => ["xdmcp"],
          "convert_to"      => []
        },
        # See bug #118196 for more information
        "fam"          => {
          "rpc_ports"  => ["sgi_fam"],
          "convert_to" => []
        },
        # requested by thofmann
        "open-pbs"     => {
          # /etc/services says: The following entries are invalid, but needed
          "tcp_ports"  => [
            "pbs",
            "pbs_mom",
            "pbs_resmom",
            "pbs_sched"
          ],
          "udp_ports"  => ["pbs_resmom"],
          "convert_to" => []
        },
        "mysql-server" => {
          "tcp_ports"  => ["mysql"],
          "convert_to" => ["service:mysql"]
        },
        "iscsi-server" => {
          "tcp_ports"  => ["iscsi-target"],
          "convert_to" => ["service:iscsitarget"]
        }
      }
    end

    # Returns whether the service ID is defined by package.
    # Returns 'false' if it isn't.
    #
    # @param [String] service
    # @return	[Boolean] whether service is defined by package
    #
    # @example
    #   ServiceDefinedByPackage ("http-server") -> false
    #   ServiceDefinedByPackage ("service:http-server") -> true
    def ServiceDefinedByPackage(service)
      service.start_with? DEFINED_BY_PKG_PREFIX
    end

    # Creates a file name from service name defined by package.
    # Service MUST be defined by package, otherwise it returns 'nil'.
    #
    # @param [String] service name (e.g., 'service:abc')
    # @return [String] file name (e.g., 'abc')
    #
    # @example
    #   GetFilenameFromServiceDefinedByPackage ("service:abc") -> "abc"
    #   GetFilenameFromServiceDefinedByPackage ("abc") -> nil
    def GetFilenameFromServiceDefinedByPackage(service)
      if !ServiceDefinedByPackage(service)
        log.error "Service #{service} is not defined by package"
        return nil
      end

      service[/\A#{DEFINED_BY_PKG_PREFIX}(.*)/, 1]
    end

    # Returns SCR Agent definition.
    #
    # @return [Yast::Term] with agent definition
    # @param filefullpath [String] full filename path (to read by this agent)
    # @api private
    def GetMetadataAgent(filefullpath)
      term(
        :IniAgent,
        filefullpath,

        "options"  => [
          "global_values",
          "flat",
          "read_only",
          "ignore_case_regexps"
        ],
        "comments" => [
          # jail followed by anything but jail (immediately)
          "^[ \t]*#[^#].*$",
          # comments that are not commented key:value pairs (see "params")
          # they always use two jails
          "^[ \t]*##[ \t]*[^([a-zA-Z0-9_]+:.*)]$",
          # comments with three jails and more
          "^[ \t]*###.*$",
          # jail alone
          "^[ \t]*#[ \t]*$",
          # (empty space)
          "^[ \t]*$",
          # sysconfig entries
          "^[ \t]*[a-zA-Z0-9_]+.*"
        ],
        "params"   => [
          # commented key:value pairs
          # e.g.: ## Name: service name
          { "match" => ["^##[ \t]*([a-zA-Z0-9_]+):[ \t]*(.*)[ \t]*$", "%s: %s"] }
        ]

      )
    end

    # Returns service definition.
    # See @services for the format.
    # If *silent* is `false` (the default), the method throws an exception
    # {Yast::SuSEFirewalServiceNotFound} if service is not found on disk.
    #
    # @param [String] service name (including the "service:" prefix)
    # @param [String] (optional) whether to silently return nil
    #                 when service is not found (default false)
    # @api private
    def service_details(service_name, silent = false)
      service = all_services[service_name]
      if service.nil? && !silent
        log.error "Uknown service '#{service_name}'"
        log.info "Known services: #{all_services.keys}"

        raise(
          SuSEFirewalServiceNotFound,
          _("Service with name '%{service_name}' does not exist") % { service_name: service_name }
        )
      end

      service
    end

    # Reads definition of services that can be used in FW_CONFIGURATIONS_[EXT|INT|DMZ]
    # in SuSEfirewall2.
    #
    # @return [Boolean] if successful
    # @api private
    def ReadServicesDefinedByRPMPackages
      log.info "Reading SuSEfirewall2 services from #{SERVICES_DIR}"
      @services ||= {}

      if !FileUtils.Exists(SERVICES_DIR) ||
          !FileUtils.IsDirectory(SERVICES_DIR)
        log.error "Cannot read #{SERVICES_DIR}"
        return false
      end

      all_definitions = SCR.Read(path(".target.dir"), SERVICES_DIR)
      all_definitions.reject! do |service|
        IGNORED_SERVICES.include?(service)
      end

      service_name = nil
      filefullpath = nil

      # for all files in that directory
      Builtins.foreach(all_definitions) do |filename|
        # "service:abc_server" to distinguis between dynamic definition and the static one
        service_name = DEFINED_BY_PKG_PREFIX + filename
        # Do not read already known services
        next unless @services[service_name].nil?

        filefullpath = SERVICES_DIR + filename
        @services[service_name] = {}

        # Registering sysconfig agent for this file
        if !SCR.RegisterAgent(
          path(".firewall_service_definition"),
          term(:ag_ini, term(:SysConfigFile, filefullpath))
          )
          log.error "Cannot register agent for #{filefullpath}"
          next
        end

        definition = nil
        definition_values = nil

        Builtins.foreach(@known_services_features) do |known_feature, map_key|
          definition = Convert.to_string(
            SCR.Read(
              Builtins.add(path(".firewall_service_definition"), known_feature)
            )
          )
          definition = "" if definition.nil?
          # map of services contains list of entries
          definition_values = Builtins.splitstring(definition, " \t\n")
          definition_values = Builtins.filter(definition_values) do |one_value|
            one_value != ""
          end
          @services[service_name][map_key] = definition_values
        end

        # Unregistering sysconfig agent for this file
        SCR.UnregisterAgent(path(".firewall_service_definition"))

        # Fallback for presented service
        @services[service_name]["name"] = _("Service: %{filename}") % { filename: filename }
        @services[service_name]["description"] = ""

        # Registering sysconfig agent for this file (to get metadata)
        if SCR.RegisterAgent(
          path(".firewall_service_metadata"),
          term(:ag_ini, GetMetadataAgent(filefullpath))
          )
          Builtins.foreach(@known_metadata) do |metadata_feature, metadata_key|
            definition = Convert.to_string(
              SCR.Read(
                Builtins.add(
                  path(".firewall_service_metadata"),
                  metadata_feature
                )
              )
            )
            next if definition.nil? || definition.empty?
            # call gettext to translate the metadata
            @services[service_name][metadata_key] = Builtins.dgettext(SERVICES_TEXTDOMAIN, definition)

            # bnc#893583: Sanitize metadata, do not allow using texts from template service
            case metadata_key
            when "name"
              @services[service_name][metadata_key] = filename if definition == TEMPLATE_SERVICE_NAME
            when "description"
              @services[service_name][metadata_key] = "" if definition == TEMPLATE_SERVICE_DESCRIPTION
            end
          end

          SCR.UnregisterAgent(path(".firewall_service_metadata"))
        else
          log.error "Cannot register agent for #{filefullpath} (metadata)"
        end
      end

      log.info "Services found: #{@services.keys.sort}"

      true
    end

    # Function returns if the service_id is a known (defined) service
    #
    # @param [String] service_id (including the "service:" prefix)
    # @return	[Boolean] if is known (defined)
    def IsKnownService(service_id)
      !service_details(service_id, true).nil?
    end

    # Returns list of service-ids defined by packages.
    # (including the "service:" prefix)
    #
    # @return [Array<String>] service ids
    def GetListOfServicesAddedByPackage
      all_services.keys
    end

    # Function returns needed TCP ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Array<String>] of needed TCP ports
    def GetNeededTCPPorts(service)
      service_details(service)["tcp_ports"] || []
    end

    # Function returns needed UDP ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Array<String>] of needed UDP ports
    def GetNeededUDPPorts(service)
      service_details(service)["udp_ports"] || []
    end

    # Function returns needed RPC ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Array<String>] of needed RPC ports
    def GetNeededRPCPorts(service)
      service_details(service)["rpc_ports"] || []
    end

    # Function returns needed IP protocols for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Array<String>] of needed IP protocols
    def GetNeededIPProtocols(service)
      service_details(service)["ip_protocols"] || []
    end

    # Function returns description of a firewall service
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[String] service description
    def GetDescription(service)
      service_details(service)["description"] || []
    end

    # Sets that configuration was modified
    def SetModified
      @sfws_modified = true

      nil
    end

    # Sets that configuration was not modified
    def ResetModified
      @sfws_modified = false

      nil
    end

    # Returns whether configuration was modified
    #
    # @return [Boolean] modified
    def GetModified
      @sfws_modified
    end

    # Function returns needed ports allowing broadcast
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Array<String>] of needed broadcast ports
    def GetNeededBroadcastPorts(service)
      service_details(service)["broadcast_ports"] || []
    end

    # Function returns needed ports and protocols for service.
    # Service needs to be known (installed in the system).
    # Function throws an exception SuSEFirewalServiceNotFound
    # if service is not known (undefined).
    #
    # @param [String] service (including the "service:" prefix)
    # @return	[Hash{String => Array<String>}] of needed ports and protocols
    #
    # @example
    #   GetNeededPortsAndProtocols ("service:aaa") -> {
    #           "tcp_ports"      => [ "122", "ftp-data" ],
    #           "udp_ports"      => [ "427" ],
    #           "rpc_ports"      => [ "portmap", "ypbind" ],
    #           "ip_protocols"   => [],
    #           "broadcast_ports"=> [ "427" ],
    #   }
    def GetNeededPortsAndProtocols(service)
      DEFAULT_SERVICE.merge(service_details(service))
    end

    # Immediately writes the configuration of service defined by package to the
    # service definition file. Service must be defined by package, this function
    # doesn't work for hard-coded services (SuSEFirewallServices).
    # Function throws an exception {Yast::SuSEFirewalServiceNotFound}
    # if service is not known (undefined) or it is not a service
    # defined by package.
    #
    # @param [String] service ID (e.g., "service:ssh")
    # @param [Hash{String => Array<String>] store_definition of full service definition
    # @return [Boolean] if successful (nil in case of developer's mistake)
    #
    # @see #IsKnownService
    # @see #ServiceDefinedByPackage
    #
    # @example
    #   SetNeededPortsAndProtocols (
    #           "service:something",
    #           {
    #                   "tcp_ports"      => [ "22", "ftp-data", "400:420" ],
    #                   "udp_ports"      => [ ],
    #                   "rpc_ports"      => [ "portmap", "ypbind" ],
    #                   "ip_protocols"   => [ "esp" ],
    #                   "broadcast_ports"=> [ ],
    #           }
    #   )
    def SetNeededPortsAndProtocols(service, store_definition)
      if !IsKnownService(service)
        log.error "Service #{service} is unknown"
        raise(
          SuSEFirewalServiceNotFound,
          _("Service with name '%{service_name}' does not exist") % { service_name: service }
        )
      end

      # create the filename from service name
      filename = GetFilenameFromServiceDefinedByPackage(service)
      if filename.nil? || filename == ""
        log.error "Can't operate with filename '#{filename}' created from '#{service}'"
        return false
      end

      # full path to the filename
      filefullpath = SERVICES_DIR + filename

      if !FileUtils.Exists(filefullpath)
        log.error "File '#{filefullpath}' doesn't exist"
        return false
      end

      # Registering sysconfig agent for that file
      if !SCR.RegisterAgent(
        path(".firewall_service_definition"),
        term(:ag_ini, term(:SysConfigFile, filefullpath))
        )
        log.error "Cannot register agent for #{filefullpath}"
        return false
      end

      ks_features_backward = Builtins.mapmap(@known_services_features) do |sysconfig_id, ycp_id|
        { ycp_id => sysconfig_id }
      end

      write_ok = true

      # we can have this service already in memory
      new_store_definition = deep_copy(store_definition)

      Builtins.foreach(store_definition) do |ycp_id, one_def|
        # Skipping read-only features
        next if READ_ONLY_SERVICE_FEATURES.include? ycp_id

        sysconfig_id = Ops.get(ks_features_backward, ycp_id)
        if sysconfig_id.nil?
          log.error "Unknown key '#{ycp_id}'"
          write_ok = false
          next
        end
        one_def = Builtins.filter(one_def) do |one_def_item|
          !one_def_item.nil? && one_def_item != "" &&
            !Builtins.regexpmatch(one_def_item, "^ *$")
        end
        service_entry_path = Path.new(".firewall_service_definition.#{sysconfig_id}")
        service_entry_value = one_def.join(" ")
        if !SCR.Write(service_entry_path, service_entry_value)
          log.error "Cannot write #{service_entry_value} to #{service_entry_path}",
            write_ok = false
          next
        end
        # new definition of the service
        Ops.set(new_store_definition, ycp_id, one_def)
      end

      # flush the cache to the disk
      if write_ok
        if !SCR.Write(path(".firewall_service_definition"), nil)
          log.error "Cannot write to disk!"
          write_ok = false
        else
          # not only store to disk but also to the memory
          @services[service] = new_store_definition
          SetModified()
        end
      end

      # Unregistering sysconfig agent for that file
      SCR.UnregisterAgent(path(".firewall_service_definition"))

      log.info "Call SetNeededPortsAndProtocols(#{service}, ...) result is #{write_ok}"
      write_ok
    end

    # Function returns list of possibly conflicting services.
    # Conflicting services are for instance nis-client and nis-server.
    # @deprecated we currently don't have such services - services are defined by packages.
    #
    # @return	[Array<String>] of conflicting services
    def GetPossiblyConflictServices
      []
    end

    publish variable: :OLD_SERVICES, type: "map <string, map <string, any>>"
    publish function: :ServiceDefinedByPackage, type: "boolean (string)"
    publish function: :GetFilenameFromServiceDefinedByPackage, type: "string (string)"
    publish function: :ReadServicesDefinedByRPMPackages, type: "boolean ()"
    publish function: :IsKnownService, type: "boolean (string)"
    publish function: :GetSupportedServices, type: "map <string, string> ()"
    publish function: :GetListOfServicesAddedByPackage, type: "list <string> ()"
    publish function: :GetNeededTCPPorts, type: "list <string> (string)"
    publish function: :GetNeededUDPPorts, type: "list <string> (string)"
    publish function: :GetNeededRPCPorts, type: "list <string> (string)"
    publish function: :GetNeededIPProtocols, type: "list <string> (string)"
    publish function: :GetDescription, type: "string (string)"
    publish function: :SetModified, type: "void ()"
    publish function: :ResetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :GetNeededBroadcastPorts, type: "list <string> (string)"
    publish function: :GetNeededPortsAndProtocols, type: "map <string, list <string>> (string)"
    publish function: :SetNeededPortsAndProtocols, type: "boolean (string, map <string, list <string>>)"
    publish function: :GetPossiblyConflictServices, type: "list <string> ()"
  end

  class SuSEFirewalldServicesClass < SuSEFirewallServicesClass
    include Yast::Logger

    SERVICES_DIR = ["/etc/firewalld/services", "/usr/lib/firewalld/services"]

    IGNORED_SERVICES = ["..", "."]

    def initialize
      @services = nil

      @known_services_features = {
        "TCP"     => "tcp_ports",
        "UDP"     => "udp_ports",
        "IP"      => "ip_protocols",
        "MODULES" => "modules"
      }

      @known_metadata = { "Name" => "name", "Description" => "description" }
    end

    # Reads services that can be used in FirewallD
    # @note Contrary to SF2 we do not read the full service details here
    # @note since that would mean to issue 5-6 API calls for every service
    # @note file which will take a lot of time for no particular reason.
    # @note We will read the full service information if needed in the
    # @note service_details method.
    # @return [Boolean] if successful
    # @api private
    def ReadServicesDefinedByRPMPackages
      log.info "Reading FirewallD services from #{SERVICES_DIR.join(" and ")}"

      @services ||= {}

      SuSEFirewall.api.services.each do |service_name|
        # Init everything
        @services[service_name] = {}
        @known_services_features.merge(@known_metadata).each_value do |param|
          # Set a good name for our service until we read its information
          case param
          when "description"
            # We intentionally don't call the API here. We will use it as a
            # flag to populate the full service details later on.
            @services[service_name][param] = default_service_description(service_name)
          when "name"
            # We have to call the API here because there are callers which
            # expect to at least provide a sensible service name without
            # worrying for the full service details. This is going to be
            # expensive though since the cost of calling --get-short grows
            # linearly with the number of available services :-(
            @services[service_name][param] = SuSEFirewall.api.service_short(service_name)
          else
            @services[service_name][param] = []
          end
        end
      end
    end

    # Returns service definition.
    # See @services for the format.
    # If `silent` is not defined or set to `true`, function throws an exception
    # SuSEFirewalServiceNotFound if service is not found on disk.
    #
    # @note Since we do not do full service population in ReadServicesDefinedByRPMPackages
    # @note we have to do it here but only if the service hasn't been populated
    # @note before. The way we determine if the service has been populated or not
    # @note is to look at the "description" key.
    #
    # @param [String] service name (may include the "service:" prefix)
    # @param [String] (optional) whether to silently return nil
    #                 when service is not found (default false)
    # @api private
    def service_details(service_name, silent = false)
      # Drop service: if needed
      service_name = service_name.partition(":")[2] if service_name.include?("service:")
      # If service description is the default one then we know that we haven't read the service
      # information just yet. Lets do it now
      populate_service(service_name) if all_services[service_name]["description"] ==
          default_service_description(service_name)
      service = all_services[service_name]
      if service.nil? && !silent
        log.error "Uknown service '#{service_name}'"
        log.info "Known services: #{all_services.keys}"

        raise(
          SuSEFirewalServiceNotFound,
          _("Service with name '%{service_name}' does not exist") % { service_name: service_name }
        )
      end

      service
    end

  private

    # A good default description for all services. We will use that to
    # determine if the service has been populated or not.
    #
    # @param service_name [String] The service name
    # @return [String] Default description for service
    def default_service_description(service_name)
      _("The %{service_name} Service") % { service_name: service_name.upcase }
    end

    # Populate service's internal data structures.
    #
    # @param service_name [String] The service name
    def populate_service(service_name)
      # This going to be too expensive (5 API calls per service) but this
      # is really the slowpath since we rarely need to extract so much
      # information from a service
      SuSEFirewall.api.service_modules(service_name).split(" ").each do |x|
        @services[service_name]["modules"] << x
      end
      SuSEFirewall.api.service_protocols(service_name).split(" ").each do |x|
        @services[service_name]["protocols"] << x
      end
      SuSEFirewall.api.service_ports(service_name).split(" ").each do |x|
        port_proto = x.split("/")
        @services[service_name]["tcp_ports"] << port_proto[0] if port_proto[1] == "tcp"
        @services[service_name]["udp_ports"] << port_proto[0] if port_proto[1] == "udp"
      end
      @services[service_name]["description"] = SuSEFirewall.api.service_description(service_name)

      log.debug("Added service '#{service_name}' with info: #{@services[service_name]}")

      true
    end

    publish function: :ReadServicesDefinedByRPMPackages, type: "boolean ()"
    publish function: :GetSupportedServices, type: "map <string, string> ()"
  end

  SuSEFirewallServices = SuSEFirewallServicesClass.create
  SuSEFirewallServices.main if SuSEFirewallServices.is_a?(SuSEFirewall2ServicesClass)
end
