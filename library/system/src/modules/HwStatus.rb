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
# File:
#  HwStatus.ycp
#
# Module:
#  HwStatus
#
# Authors:
#  Klaus Kaempf (kkaempf@suse.de)
#
# Summary:
#  All hardware status relevant functions are here
# $Id$
require "yast"

module Yast
  class HwStatusClass < Module
    def main
      # status map for devices, key is "unique id", value is symbol (`yes, `no)

      @statusmap = {}
    end

    # Set
    # set status for a hardware device
    # @param [String] id  string, unique-id for device
    # @param [Symbol] stat  symbol, status of device (`yes or `no)
    #
    def Set(id, stat)
      Ops.set(@statusmap, id, stat)

      nil
    end

    # Get()
    # get status for device
    # @param [String] id  string, unique-id for device
    # @return [Symbol]  status of device, (`yes or `no)
    #      returns `unknown if status wasn't set before
    def Get(id)
      Ops.get(@statusmap, id, :unknown)
    end

    # Save()
    # save stati for all devices
    def Save
      Builtins.foreach(@statusmap) do |id, stat|
        Builtins.y2milestone("Setting status of %1 as %2", id, stat)
        SCR.Write(path(".probe.status.configured"), id, stat)
      end

      nil
    end

    # Update()
    # set stati for all devices
    def Update
      # probe all pci and isapnp devices once
      # so they have a defined status after update
      SCR.Read(path(".probe.pci"))
      SCR.Read(path(".probe.isapnp"))

      # build relation between old keys and new UDIs (bug #104676)
      command = "/usr/sbin/hwinfo --pci --block --mouse --save-config=all"
      Builtins.y2milestone("Running %1", command)
      cmdret = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      exit = Ops.get_integer(cmdret, "exit", -1)
      Builtins.y2milestone(
        "Command retval: %1",
        Ops.get_integer(cmdret, "exit", -1)
      )
      if exit != 0
        Builtins.y2error("Command output: %1", cmdret)
      else
        Builtins.y2debug("Command output: %1", cmdret)
      end

      nil
    end

    publish function: :Set, type: "void (string, symbol)"
    publish function: :Get, type: "symbol (string)"
    publish function: :Save, type: "void ()"
    publish function: :Update, type: "void ()"
  end

  HwStatus = HwStatusClass.new
  HwStatus.main
end
