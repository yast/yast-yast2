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
# File:	modules/Address.ycp
# Package:	yast2
# Summary:	Address manipulation routines
# Authors:	Michal Svec <msvec@suse.cz>
# Flags:	Stable
#
# $Id$
#
# Address is a hostname (either FQ or simple, or IP address)
require "yast"

module Yast
  class AddressClass < Module
    def main
      textdomain "base"

      Yast.import "Hostname"
      Yast.import "IP"

      @ValidChars = Ops.add(Hostname.ValidChars, IP.ValidChars)
      @ValidChars4 = Ops.add(Hostname.ValidChars, IP.ValidChars4)
      @ValidChars6 = Ops.add(Hostname.ValidChars, IP.ValidChars6)
      @ValidCharsMAC = "0123456789abcdefABCDEF:"
    end

    # Return a description of a valid address (ip4 or name)
    # @return description
    def Valid4
      Ops.add(Ops.add(IP.Valid4, "\n"), Hostname.ValidFQ)
    end

    # Check syntax of a network address (ip4 or name)
    # @param [String] address an address
    # @return true if correct
    def Check4(address)
      IP.Check4(address) || Hostname.CheckFQ(address)
    end

    # Check syntax of a network address (ip6 or name)
    # @param [String] address an address
    # @return true if correct
    def Check6(address)
      IP.Check6(address) || Hostname.CheckFQ(address)
    end

    # Check syntax of a network address (IP address or hostname)
    # @param [String] address an address
    # @return true if correct
    def Check(address)
      Check4(address) || Check6(address)
    end

    # Describe a valid MAC address
    # @return [String] description of a valid MAC address
    def ValidMAC
      #describe valid MAC address
      _(
        "A valid MAC address consists of six pairs of hexadecimal\ndigits separated by colons."
      )
    end

    # Check syntax of MAC address
    # @param [String] address MAC address
    # @return true if correct
    def CheckMAC(address)
      return false if address == nil || address == ""

      regexp = "[0-9a-fA-F]{2,2}"
      regexp = Builtins.sformat("(%1:){5,5}%1", regexp)

      Builtins.regexpmatch(address, regexp)
    end

    publish variable: :ValidChars, type: "string"
    publish variable: :ValidChars4, type: "string"
    publish variable: :ValidChars6, type: "string"
    publish variable: :ValidCharsMAC, type: "string"
    publish function: :Valid4, type: "string ()"
    publish function: :Check4, type: "boolean (string)"
    publish function: :Check6, type: "boolean (string)"
    publish function: :Check, type: "boolean (string)"
    publish function: :ValidMAC, type: "string ()"
    publish function: :CheckMAC, type: "boolean (string)"
  end

  Address = AddressClass.new
  Address.main
end
