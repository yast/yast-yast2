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
#	HWConfig.ycp
#
# Module:
#	HWConfig
#
# Authors:
#	Ladislav Slezak <lslezak@suse.cz>
#
# Summary:
#	Module for accessing hardware configuration files (/etc/sysconfig/hwcfg-*)
#
# Flags: Stable
#
# $Id$
require "yast"

module Yast
  class HWConfigClass < Module
    def main
      textdomain "base"
    end

    # Return list of all available hardware configuration files
    # @return [Array<String>] found files
    def ConfigFiles
      # read all files
      all = SCR.Dir(path(".sysconfig.hardware.section"))

      all = [] if all == nil

      modules = Builtins.filter(all) do |file|
        !Builtins.regexpmatch(file, "[~]")
      end

      Builtins.y2debug("config files=%1", modules)

      deep_copy(all)
    end

    # Return list of all available variable in the configuration file
    # @param [String] file to search
    # @return [Array<String>] found variables
    def Variables(file)
      p = Ops.add(path(".sysconfig.hardware.value"), file)

      values = SCR.Dir(p)
      Builtins.y2debug("values=%1", values)

      deep_copy(values)
    end

    # Read all values from the file
    # @param [String] file configuration file to read
    # @return [Hash] map $[ "VARIABLE" : "value" ]
    def Values(file)
      vars = Variables(file)
      ret = {}
      p = Ops.add(path(".sysconfig.hardware.value"), file)

      Builtins.maplist(vars) do |var|
        item = Convert.to_string(SCR.Read(Ops.add(p, var)))
        Ops.set(ret, var, item) if item != nil
      end

      deep_copy(ret)
    end

    # Set value of the variable in the config file
    # @param [String] file config file
    # @param [String] variable name of the variable
    # @param [String] value the new value
    # @return [Boolean] true on success
    def SetValue(file, variable, value)
      SCR.Write(
        Ops.add(Ops.add(path(".sysconfig.hardware.value"), file), variable),
        value
      )
    end

    # Set comment of the variable in the config file
    # @param [String] file config file
    # @param [String] variable name of the variable
    # @return [String] comment the new comment
    def GetValue(file, variable)
      Convert.to_string(
        SCR.Read(
          Ops.add(Ops.add(path(".sysconfig.hardware.value"), file), variable)
        )
      )
    end

    # Set comment of the variable in the config file
    # @param [String] file config file
    # @param [String] variable name of the variable
    # @param [String] comment the new comment, the comment must be terminated by "\n" chacter!
    # @return [Boolean] true on success
    def SetComment(file, variable, comment)
      SCR.Write(
        Ops.add(
          Ops.add(path(".sysconfig.hardware.value_comment"), file),
          variable
        ),
        comment
      )
    end

    # Get comment of the variable from the config file
    # @param [String] file config file
    # @param [String] variable name of the variable
    # @return [String] comment of the variable
    def GetComment(file, variable)
      Convert.to_string(
        SCR.Read(
          Ops.add(
            Ops.add(path(".sysconfig.hardware.value_comment"), file),
            variable
          )
        )
      )
    end

    # Remove configuration file from system
    # @param [String] file config name
    # @return true on success
    def RemoveConfig(file)
      p = Ops.add(path(".sysconfig.hardware.section"), file)
      Builtins.y2debug("deleting: %1", file)
      SCR.Write(p, nil)
    end

    # Flush - write the changes to files
    # @return true on success
    def Flush
      # save all changes
      SCR.Write(path(".sysconfig.hardware"), nil)
    end

    publish function: :ConfigFiles, type: "list <string> ()"
    publish function: :Variables, type: "list <string> (string)"
    publish function: :Values, type: "map <string, string> (string)"
    publish function: :SetValue, type: "boolean (string, string, string)"
    publish function: :GetValue, type: "string (string, string)"
    publish function: :SetComment, type: "boolean (string, string, string)"
    publish function: :GetComment, type: "string (string, string)"
    publish function: :RemoveConfig, type: "boolean (string)"
    publish function: :Flush, type: "boolean ()"
  end

  HWConfig = HWConfigClass.new
  HWConfig.main
end
