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
# File:	modules/NetworkConfig.ycp
# Package:	Network configuration
# Summary:	Network configuration data
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Representation of the configuration of network cards.
# Input and output routines.
# A simple container for /etc/sysconfig/network/{config,dhcp}
require "yast"

module Yast
  class NetworkConfigClass < Module
    def main
      Yast.import "String"

      # Basic network settings (/etc/sysconfig/network/config)
      @Config = {}

      # DHCP settings (/etc/sysconfig/network/dhcp)
      @DHCP = {}

      # Basic network settings
      @Orig_Config = nil

      # DHCP settings
      @Orig_DHCP = nil

      #--------------
      # PRIVATE DATA

      # True if data are already read
      @initialized = false
    end

    # Read sysconfig file.
    # Uses metadata to distinguish between booleans, integers, and strings
    # @param [Yast::Path] config sysconfig file SCR path
    # @return sysconfig file contents
    def ReadConfig(config)
      Builtins.y2debug("config=%1", config)
      return {} if config.nil?
      ret = {}

      vars = SCR.Dir(config)
      vars = [] if vars.nil?
      Builtins.maplist(vars) do |var|
        varpath = Builtins.add(config, var)
        comment = Convert.to_string(SCR.Read(Builtins.add(varpath, "comment")))
        if Builtins.regexpmatch(
          comment,
          Ops.add(Ops.add("^.*## Type:[ \t]*([", String.CLower), "]*).*$")
        )
          comment = Builtins.regexpsub(
            comment,
            Ops.add(Ops.add("^.*## Type:[ \t]*([", String.CLower), "]*).*$"),
            "\\1"
          )
        end
        val = Convert.to_string(SCR.Read(varpath))
        Builtins.y2debug("%1[%2]=%3", var, comment, val)
        if !val.nil?
          if comment == "yesno" || val == "yes" || val == "no"
            Ops.set(ret, var, val == "yes")
          elsif comment == "integer"
            Ops.set(ret, var, Builtins.tointeger(val)) if val != ""
          else
            Ops.set(ret, var, val)
          end
        end
      end
      ret = {} if ret.nil?
      Builtins.y2debug("ret=%1", ret)
      deep_copy(ret)
    end

    # Write sysconfig file
    # @param [Yast::Path] config sysconfig file SCR path
    # @param [Hash] data sysconfig file contents
    # @return true if success
    def WriteConfig(config, data)
      data = deep_copy(data)
      Builtins.y2debug("config=%1", config)
      Builtins.y2debug("data=%1", data)

      return false if config.nil? || data.nil?

      changed = false
      Builtins.maplist(
        Convert.convert(data, from: "map", to: "map <string, any>")
      ) do |var, val|
        oldval = Convert.to_string(SCR.Read(Builtins.add(config, var)))
        newval = if Ops.is_boolean?(val)
          Convert.to_boolean(val) ? "yes" : "no"
        else
          Builtins.sformat("%1", val)
        end
        if oldval.nil? || oldval != newval
          SCR.Write(Builtins.add(config, var), newval)
          changed = true
        end
      end
      SCR.Write(config, nil) if changed == true

      Builtins.y2debug("changed=%1", changed)
      true
    end

    #------------------
    # GLOBAL FUNCTIONS

    # Data was modified?
    # @return true if modified
    def Modified
      ret = @DHCP != @Orig_DHCP || @Config != @Orig_Config
      Builtins.y2debug("ret=%1", ret)
      ret
    end

    # Read all network settings from the SCR
    # @return true on success
    def Read
      return true if @initialized == true

      @Config = ReadConfig(path(".sysconfig.network.config"))
      @DHCP = ReadConfig(path(".sysconfig.network.dhcp"))

      @Orig_Config = Builtins.eval(@Config)
      @Orig_DHCP = Builtins.eval(@DHCP)

      @initialized = true
      true
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write
      Builtins.y2milestone("Writing configuration")
      if !Modified()
        Builtins.y2milestone("No changes to NetworkConfig -> nothing to write")
        return true
      end

      WriteConfig(path(".sysconfig.network.dhcp"), @DHCP)
      WriteConfig(path(".sysconfig.network.config"), @Config)

      true
    end

    # Import data
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = deep_copy(settings)
      @Config = Builtins.eval(Ops.get_map(settings, "config", {}))
      @DHCP = Builtins.eval(Ops.get_map(settings, "dhcp", {}))

      @Orig_Config = nil
      @Orig_DHCP = nil

      true
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export
      Builtins.eval("config" => @Config, "dhcp" => @DHCP)
    end

    publish variable: :Config, type: "map"
    publish variable: :DHCP, type: "map"
    publish function: :Modified, type: "boolean ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
  end

  NetworkConfig = NetworkConfigClass.new
  NetworkConfig.main
end
