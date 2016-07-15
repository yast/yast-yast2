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
#	ModulesConf.ycp
#
# Module:
#	ModulesConf
#
# Authors:
#	Klaus Kaempf (kkaempf@suse.de)
#
# Summary:
#	All modules.conf related functions are here
#
# $Id$
require "yast"

module Yast
  class ModulesConfClass < Module
    def main
      Yast.import "Arch"
      Yast.import "Misc"
      Yast.import "Mode"

      textdomain "base"

      @modules = {}
    end

    # ModuleArgs
    # save arguments for a kernel module
    # @param [String] name	string, name of kernel module
    # @param [String] arg	string, arguments ("opt1=val1 opt2=val2 ...")
    def ModuleArgs(name, arg)
      return if name == ""

      moduledata = Ops.get(@modules, name, {})
      Ops.set(moduledata, "options", arg) if arg != ""
      Ops.set(@modules, name, moduledata)

      nil
    end

    # RunDepmod
    # runs /sbin/depmod
    # !! call only when SCR runs on target !!
    # @param [Boolean] force	boolean, force depmod run (option "-a" instead of "-A")
    def RunDepmod(force)
      Yast.import "Kernel"

      kernel_version = Convert.to_string(
        SCR.Read(
          path(".boot.vmlinuz_version"),
          [Ops.add("/boot/", Kernel.GetBinary)]
        )
      )

      Builtins.y2milestone("running /sbin/depmod")

      if Ops.greater_than(Builtins.size(kernel_version), 0)
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(
                "unset MODPATH; /sbin/depmod " + (force ? "-a" : "-A") +
                  " -F /boot/System.map-",
                kernel_version
              ),
              " "
            ),
            kernel_version
          )
        )
      else
        SCR.Execute(
          path(".target.bash"),
          "unset MODPATH; /sbin/depmod " + (force ? "-a" : "-A") +
            " -F /boot/System.map-`uname -r` `uname -r`"
        )
      end

      nil
    end

    # Save
    # save module names and arguments to /etc/modules.conf
    # @param [Boolean] force	boolean, force depmod run even if /etc/modules.conf is unchanged
    # !! call only when SCR runs on target !!
    def Save(force)
      # make module names to one long string
      # start with modules from linuxrc

      # write module options to modules.conf, mk_initrd handles the rest

      modules_conf_changed = false

      Builtins.foreach(@modules) do |mname, mdata|
        options = Ops.get_string(mdata, "options", "")
        if options != ""
          # we have options, pass them to modules.conf

          current_options = Convert.to_map(
            SCR.Read(Builtins.add(path(".modules.options"), mname))
          )

          new_options = Misc.SplitOptions(options, current_options)

          SCR.Write(Builtins.add(path(".modules.options"), mname), new_options)
          modules_conf_changed = true
        end
      end

      # Network module handling removed (#39135)
      # #24836, Alias needs special treatment because of multiple cards

      # if needed, re-write /etc/modules.conf and run /sbin/depmod

      SCR.Write(path(".modules"), nil) if modules_conf_changed

      RunDepmod(true) if (modules_conf_changed || force) && !Mode.test

      nil
    end

    publish function: :ModuleArgs, type: "void (string, string)"
    publish function: :RunDepmod, type: "void (boolean)"
    publish function: :Save, type: "void (boolean)"
  end

  ModulesConf = ModulesConfClass.new
  ModulesConf.main
end
