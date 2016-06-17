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
# File:	modules/Netmask.ycp
# Module:	yast2
# Summary:	Netmask manipulation routines
# Authors:	Michal Svec <msvec@suse.cz>
# Flags:	Stable
#
# $Id$
require "yast"

module Yast
  class NetmaskClass < Module
    def main
      textdomain "base"

      @ValidChars = "0123456789."
      @ValidChars4 = "0123456789."
      @ValidChars6 = "0123456789"
    end

    def CheckPrefix4(prefix)
      return false if prefix.nil? || prefix == ""
      # <0,32>
      return false unless Builtins.regexpmatch(prefix, "^[0-9]+$")

      nm = Builtins.tointeger(prefix)
      Ops.greater_or_equal(nm, 0) && Ops.less_or_equal(nm, 32)
    end

    # Check the IPv4 netmask
    # Note that 0.0.0.0 is not a correct netmask.
    # @param [String] netmask network mask
    # @return true if correct
    def Check4(netmask)
      return false if netmask.nil? || netmask == ""

      # 255.255.240.0
      s1 = "(128|192|224|240|248|252|254|255)"
      nm = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(Ops.add(Ops.add("^(", s1), ".0.0.0|"), "255."),
                      s1
                    ),
                    ".0.0|"
                  ),
                  "255.255."
                ),
                s1
              ),
              ".0|"
            ),
            "255.255.255."
          ),
          s1
        ),
        ")$"
      )
      Builtins.regexpmatch(netmask, nm)
    end

    # Check the IPv6 netmask
    # @param [String] netmask network mask
    # @return true if correct
    def Check6(netmask)
      return false if netmask.nil? || netmask == ""

      # <0,256>
      return false if !Builtins.regexpmatch(netmask, "^[0-9]+$")
      nm = Builtins.tointeger(netmask)
      Ops.greater_or_equal(nm, 0) && Ops.less_or_equal(nm, 256)
    end

    # Check the netmask
    # @param [String] netmask network mask
    # @return true if correct
    def Check(netmask)
      Check4(netmask) || Check6(netmask)
    end

    #
    # Convert netmask in bits form (20) to IPv4 netmask string (255.255.240.0)
    #
    # @param bits  number of bits in netmask
    # @return      netmask string or empty string in case of invalid bits (e.g.
    #              when prefix is incompatible with IPv4)
    #
    def FromBits(bits)
      return "" unless bits.between?(0, 32)

      b = Ops.divide(bits, 8)
      d = Ops.modulo(bits, 8)

      l = {
        1 => "255.",
        2 => "255.255.",
        3 => "255.255.255.",
        4 => "255.255.255.255"
      }
      r = { 3 => "0", 2 => "0.0", 1 => "0.0.0", 0 => "0.0.0.0" }
      m = {
        1 => "128",
        2 => "192",
        3 => "224",
        4 => "240",
        5 => "248",
        6 => "252",
        7 => "254",
        8 => "255"
      }

      Ops.add(
        Ops.add(
          Ops.get_string(l, b, ""),
          if d != 0
            Ops.add(Ops.get_string(m, d, ""), b != 3 ? "." : "")
          else
            ""
          end
        ),
        Ops.get_string(r, d == 0 ? b : Ops.add(b, 1), "")
      )
    end

    # Convert IPv4 netmask as string (255.255.240.0) to bits form (20)
    # @param [String] netmask netmask as string
    # @return number of bits in netmask; 32 for empty string
    def ToBits(netmask)
      return 32 if netmask == ""
      bits = 0
      m = {
        "128" => 1,
        "192" => 2,
        "224" => 3,
        "240" => 4,
        "248" => 5,
        "252" => 6,
        "254" => 7,
        "255" => 8
      }
      Builtins.maplist(Builtins.splitstring(netmask, ".")) do |i|
        bits = Ops.add(bits, Ops.get_integer(m, i, 0))
      end
      bits
    end

    publish variable: :ValidChars, type: "string"
    publish variable: :ValidChars4, type: "string"
    publish variable: :ValidChars6, type: "string"
    publish function: :CheckPrefix4, type: "boolean (string)"
    publish function: :Check4, type: "boolean (string)"
    publish function: :Check6, type: "boolean (string)"
    publish function: :Check, type: "boolean (string)"
    publish function: :FromBits, type: "string (integer)"
    publish function: :ToBits, type: "integer (string)"
  end

  Netmask = NetmaskClass.new
  Netmask.main
end
