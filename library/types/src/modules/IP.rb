# encoding: utf-8

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
# File:	modules/IP.ycp
# Module:	yast2
# Summary:	IP manipulation routines
# Authors:	Michal Svec <msvec@suse.cz>
# Flags:	Stable
#
# $Id$
require "yast"

module Yast
  class IPClass < Module
    def main
      textdomain "base"

      Yast.import "Netmask"

      @ValidChars = "0123456789abcdefABCDEF.:"
      @ValidChars4 = "0123456789."
      @ValidChars6 = "0123456789abcdefABCDEF:"

      # helper list, each bit has its decimal representation
      @bit_weight_row = [128, 64, 32, 16, 8, 4, 2, 1]
    end

    # Describe a valid IPv4 address
    # @return [String] describtion a valid IPv4 address
    def Valid4
      #Translators: dot: "."
      _(
        "A valid IPv4 address consists of four integers\nin the range 0-255 separated by dots."
      )
    end

    # Check syntax of IPv4 address
    # @param [String] ip IPv4 address
    # @return true if correct
    def Check4(ip)
      return false if ip == nil || ip == ""
      num = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])"
      ipv4 = Ops.add(Ops.add(Ops.add(Ops.add("^", num), "(\\."), num), "){3}$")
      Builtins.regexpmatch(ip, ipv4)
    end

    # Check syntax of IPv4 address (maybe better)
    # @param ip IPv4 address
    # @return true if correct
    # global defin boolean Check4_new(string ip) ``{
    #     if(ip == nil || ip == "") return false;
    #     string num0 = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])";
    #     string num1 = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])";
    #     string ipv4 = "^" + num0 + "(\\." + num1 + "){3}$";
    #     return regexpmatch(ip, ipv4);
    # }

    # Describe a valid IPv6 address
    # @return [String] describtion a valid IPv4 address
    def Valid6
      #Translators: colon: ":"
      _(
        "A valid IPv6 address consists of up to eight\n" +
          "hexadecimal numbers in the range 0 - FFFF separated by colons.\n" +
          "It can contain up to one double colon."
      )
    end

    # Check syntax of IPv6 address
    # @param [String] ip IPv6 address
    # @return true if correct
    def Check6(ip)
      return false if ip == nil || ip == ""

      #string num = "([1-9a-fA-F][0-9a-fA-F]*|0)";
      num = "([0-9a-fA-F]{1,4})"

      # 1:2:3:4:5:6:7:8
      if Builtins.regexpmatch(
          ip,
          Ops.add(Ops.add(Ops.add(Ops.add("^", num), "(:"), num), "){7}$")
        )
        return true
      end
      # ::3:4:5:6:7:8
      if Builtins.regexpmatch(ip, Ops.add(Ops.add("^:(:", num), "){1,6}$"))
        return true
      end
      # 1:2:3:4:5:6::
      if Builtins.regexpmatch(ip, Ops.add(Ops.add("^(", num), ":){1,6}:$"))
        return true
      end
      # :: only once
      return false if Builtins.regexpmatch(ip, "::.*::")
      # : max 7x
      return false if Builtins.regexpmatch(ip, "^([^:]*:){8,}")
      # 1:2:3::5:6:7:8
      # 1:2:3:4:5:6::8
      if Builtins.regexpmatch(
          ip,
          Ops.add(
            Ops.add(Ops.add(Ops.add("^(", num), ":){1,6}(:"), num),
            "){1,6}$"
          )
        )
        return true
      end

      false
    end

    # If param contains IPv6 in one of its various forms, extracts it.
    #
    # if ip is closed in [ ] or contain % then it can be special case of IPv6 syntax,
    # so extract ipv6 (see description later) and continue with check.
    #
    # IPv6 syntax:
    # - pure ipv6 blob (e.g. f008::1)
    # - ipv6 blob with link local suffix (e.g. f008::1%eth0)
    # - dtto in square brackets (e.g. [f008::1%eth0] )
    #
    # @param [String] ip    a buffer with address
    # @return      IPv6 part of ip param, unchanged ip param otherwise
    def UndecorateIPv6(ip)
      if Builtins.regexpmatch(ip, "^\\[.*\\]") ||
          Builtins.regexpmatch(ip, "^[^][%]+(%[^][%]+){0,1}$")
        ip = Builtins.regexpsub(
          ip,
          "^\\[?([^][%]+)(%[^][%]+){0,1}(\\]|$)",
          "\\1"
        )
      end

      ip
    end

    # Check syntax of IP address
    # @param [String] ip IP address
    # @return true if correct
    def Check(ip)
      Check4(ip) || Check6(ip)
    end

    # Returns string of valid network definition.
    # Both IPv4 and IPv6.
    #
    # @return [String] describing the valid network.
    def ValidNetwork
      # TRANSLATORS: description of the valid network definition
      _(
        "A valid network definition can contain the IP,\n" +
          "IP/Netmask, IP/Netmask_Bits, or 0/0 for all networks.\n" +
          "\n" +
          "Examples:\n" +
          "IP: 192.168.0.1 or 2001:db8:0::1\n" +
          "IP/Netmask: 192.168.0.0/255.255.255.0 or 2001:db8:0::1/56\n" +
          "IP/Netmask_Bits: 192.168.0.0/24 or 192.168.0.1/32 or 2001:db8:0::1/ffff::0\n"
      )
    end

    # Convert IPv4 address from string to integer
    # @param [String] ip IPv4 address
    # @return ip address as integer
    def ToInteger(ip)
      # FIXME: Check4, also to Compute*
      l = Builtins.maplist(Builtins.splitstring(ip, ".")) do |e|
        Builtins.tointeger(e)
      end
      Ops.add(
        Ops.add(
          Ops.add(
            Ops.get_integer(l, 3, 0),
            Ops.shift_left(Ops.get_integer(l, 2, 0), 8)
          ),
          Ops.shift_left(Ops.get_integer(l, 1, 0), 16)
        ),
        Ops.shift_left(Ops.get_integer(l, 0, 0), 24)
      )
    end

    # Convert IPv4 address from integer to string
    # @param [Fixnum] ip IPv4 address
    # @return ip address as string
    def ToString(ip)
      l = Builtins.maplist([16777216, 65536, 256, 1]) do |b|
        Ops.bitwise_and(Ops.divide(ip, b), 255)
      end
      Builtins.sformat(
        "%1.%2.%3.%4",
        Ops.get_integer(l, 0, 0),
        Ops.get_integer(l, 1, 0),
        Ops.get_integer(l, 2, 0),
        Ops.get_integer(l, 3, 0)
      )
    end

    # Converts IPv4 address from string to hex format
    # @param [String] ip IPv4 address as string in "ipv4" format
    # @return [String] representing IP in Hex
    # @example IP::ToHex("192.168.1.1") -> "0xC0A80101"
    # @example IP::ToHex("10.10.0.1") -> "0x0A0A0001"
    def ToHex(ip)
      tmp = Ops.add(
        "00000000",
        Builtins.substring(
          Builtins.toupper(Builtins.tohexstring(ToInteger(ip))),
          2
        )
      )
      Builtins.substring(tmp, Ops.subtract(Builtins.size(tmp), 8))
    end

    # Compute IPv4 network address from ip4 address and network mask.
    # @param [String] ip IPv4 address
    # @param [String] mask netmask
    # @return computed subnet
    def ComputeNetwork(ip, mask)
      i = ToInteger(ip)
      m = ToInteger(mask)
      ToString(Ops.bitwise_and(Ops.bitwise_and(i, m), 4294967295))
    end

    # Compute IPv4 broadcast address from ip4 address and network mask.
    #
    # The broadcast address is the highest address of network address range.
    # @param [String] ip IPv4 address
    # @param [String] mask netmask
    # @return computed broadcast
    def ComputeBroadcast(ip, mask)
      i = ToInteger(ip)
      m = ToInteger(mask)
      ToString(
        Ops.bitwise_and(Ops.bitwise_or(i, Ops.bitwise_not(m)), 4294967295)
      )
    end

    # Converts IPv4 into its 32 bit binary representation.
    #
    # @param [String] ipv4
    # @return [String] binary
    #
    # @see #BitsToIPv4()
    #
    # @example
    #     IPv4ToBits("80.25.135.2")    -> "01010000000110011000011100000010"
    #     IPv4ToBits("172.24.233.211") -> "10101100000110001110100111010011"
    def IPv4ToBits(ipv4)
      if !Check4(ipv4)
        Builtins.y2error("Not a valid IPv4: %1", ipv4)
        return nil
      end

      ret = ""
      Builtins.foreach(Builtins.splitstring(ipv4, ".")) do |ipv4_part|
        ipv4_part_i = Builtins.tointeger(ipv4_part)
        Builtins.foreach(@bit_weight_row) do |try_i|
          if Ops.greater_than(Ops.divide(ipv4_part_i, try_i), 0)
            ipv4_part_i = Ops.modulo(ipv4_part_i, try_i)
            ret = Ops.add(ret, "1")
          else
            ret = Ops.add(ret, "0")
          end
        end
      end

      ret
    end

    # Converts 32 bit binary number to its IPv4 repserentation.
    #
    # @param string binary
    # @return [String] ipv4
    #
    # @see #IPv4ToBits()
    #
    # @example
    #     BitsToIPv4("10111100000110001110001100000101") -> "188.24.227.5"
    #     BitsToIPv4("00110101000110001110001001100101") -> "53.24.226.101"
    def BitsToIPv4(bits)
      if Builtins.size(bits) != 32
        Builtins.y2error("Not a valid IPv4 in Bits: %1", bits)
        return nil
      end
      if !Builtins.regexpmatch(bits, "^[01]+$")
        Builtins.y2error("Not a valid IPv4 in Bits: %1", bits)
        return nil
      end

      ipv4 = ""
      position = 0
      while Ops.less_than(position, 32)
        ip_part = 0
        eight_bits = Builtins.substring(bits, position, 8)

        counter = -1
        while Ops.less_than(counter, 8)
          counter = Ops.add(counter, 1)
          one_bit = Builtins.substring(eight_bits, counter, 1)

          if one_bit == "1"
            ip_part = Ops.add(ip_part, Ops.get(@bit_weight_row, counter, 0))
          end
        end

        ipv4 = Ops.add(
          Ops.add(ipv4, ipv4 != "" ? "." : ""),
          Builtins.tostring(ip_part)
        )
        position = Ops.add(position, 8)
      end

      ipv4
    end

    def CheckNetworkShared(network)
      if network == nil || network == ""
        return false 

        # all networks
      elsif network == "0/0"
        return true
      end

      nil
    end

    # Checks the given IPv4 network entry.
    #
    # @see CheckNetwork for details.
    # @see CheckNetwork6 for IPv6 version of the same function.
    #
    # @example
    #   CheckNetwork("192.168.0.0/255.255.255.0") -> true
    #   CheckNetwork("192.168.1.22") -> true
    #   CheckNetwork("172.55.0.0/33") -> false
    def CheckNetwork4(network)
      generic_check = CheckNetworkShared(network)
      if generic_check != nil
        return generic_check 

        # 192.168.0.1, 0.8.55.999
      elsif Check4(network)
        return true 

        # 192.168.0.0/20, 0.8.55/158
      elsif Builtins.regexpmatch(
          network,
          Ops.add(Ops.add("^[", @ValidChars4), "]+/[0-9]+$")
        )
        net_parts = Builtins.splitstring(network, "/")
        return Check4(Ops.get(net_parts, 0, "")) &&
          Netmask.CheckPrefix4(Ops.get(net_parts, 1, "")) 

        # 192.168.0.0/255.255.255.0, 0.8.55/10.258.12
      elsif Builtins.regexpmatch(
          network,
          Ops.add(
            Ops.add(Ops.add(Ops.add("^[", @ValidChars4), "]+/["), @ValidChars4),
            "]+$"
          )
        )
        net_parts = Builtins.splitstring(network, "/")
        return Check4(Ops.get(net_parts, 0, "")) &&
          Netmask.Check4(Ops.get(net_parts, 1, ""))
      end

      false
    end

    # Checks the given IPv6 network entry.
    #
    # @see CheckNetwork for details.
    # @see CheckNetwork4 for IPv4 version of the same function.
    #
    # @example
    #   CheckNetwork("2001:db8:0::1/64") -> true
    #   CheckNetwork("2001:db8:0::1") -> true
    #   CheckNetwork("::1/257") -> false
    def CheckNetwork6(network)
      generic_check = CheckNetworkShared(network)
      if generic_check != nil
        return generic_check 

        # 2001:db8:0::1
      elsif Check6(network)
        return true 

        # 2001:db8:0::1/64
      elsif Builtins.regexpmatch(
          network,
          Ops.add(
            Ops.add(
              Ops.add(Ops.add("^[", @ValidChars6), "]+/["),
              Netmask.ValidChars6
            ),
            "]+$"
          )
        )
        net_parts = Builtins.splitstring(network, "/")
        return Check6(Ops.get(net_parts, 0, "")) &&
          Netmask.Check6(Ops.get(net_parts, 1, "")) 

        # 2001:db8:0::1/ffff:ffff::0
      elsif Builtins.regexpmatch(
          network,
          Ops.add(
            Ops.add(Ops.add(Ops.add("^[", @ValidChars6), "]+/["), @ValidChars6),
            "]+$"
          )
        )
        net_parts = Builtins.splitstring(network, "/")
        return Check6(Ops.get(net_parts, 0, "")) &&
          Check6(Ops.get(net_parts, 1, ""))
      end

      false
    end

    # Checks the given network entry which can be defined in several formats:
    #   - Single IPv4 or IPv6, e.g., 192.168.0.1 or 2001:db8:0::1
    #   - IP/Netmask, e.g., 192.168.0.0/255.255.255.0 or 2001:db8:0::1/ffff:ffff::0
    #   - IP/CIDR, e.g., 192.168.0.0/20 or 2001:db8:0::1/56
    #
    # @example
    #  CheckNetwork("192.168.0.1") -> true
    #  CheckNetwork("192.168.0.0/20") -> true
    #  CheckNetwork("192.168.0.0/255.255.255.0") -> true
    #  CheckNetwork("0/0") -> true
    #  CheckNetwork("::1/128") -> true
    #  CheckNetwork("2001:db8:0::1") -> true
    #  CheckNetwork("2001:db8:0::1/64") -> true
    #  CheckNetwork("2001:db8:0::1/ffff:ffff::0") -> true
    #  CheckNetwork("2001:db8:0::xyz") -> false
    #  CheckNetwork("::1/257") -> false
    #  CheckNetwork("172.55.0.0/33") -> false
    #  CheckNetwork("172.55.0.0/125.85.5.5") -> false
    def CheckNetwork(network)
      CheckNetwork4(network) || CheckNetwork6(network)
    end

    publish :variable => :ValidChars, :type => "string"
    publish :variable => :ValidChars4, :type => "string"
    publish :variable => :ValidChars6, :type => "string"
    publish :function => :Valid4, :type => "string ()"
    publish :function => :Check4, :type => "boolean (string)"
    publish :function => :Valid6, :type => "string ()"
    publish :function => :Check6, :type => "boolean (string)"
    publish :function => :UndecorateIPv6, :type => "string (string)"
    publish :function => :Check, :type => "boolean (string)"
    publish :function => :ValidNetwork, :type => "string ()"
    publish :function => :ToInteger, :type => "integer (string)"
    publish :function => :ToString, :type => "string (integer)"
    publish :function => :ToHex, :type => "string (string)"
    publish :function => :ComputeNetwork, :type => "string (string, string)"
    publish :function => :ComputeBroadcast, :type => "string (string, string)"
    publish :function => :IPv4ToBits, :type => "string (string)"
    publish :function => :BitsToIPv4, :type => "string (string)"
    publish :function => :CheckNetwork4, :type => "boolean (string)"
    publish :function => :CheckNetwork6, :type => "boolean (string)"
    publish :function => :CheckNetwork, :type => "boolean (string)"
  end

  IP = IPClass.new
  IP.main
end
