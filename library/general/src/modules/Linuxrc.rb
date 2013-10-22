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
# Module:      Linuxrc
# File:	modules/Linuxrc.ycp
# Purpose:	Interaction with linuxrc
#
# Author:	Anas Nashif <nashif@suse.de?
# $Id$
require "yast"

module Yast
  class LinuxrcClass < Module
    def main
      Yast.import "Mode"
      Yast.import "Stage"

      @install_inf = nil

      @_manual = nil
    end

    # routines for reading data from /etc/install.inf

    def ReadInstallInf
      return if @install_inf != nil

      @install_inf = {}
      # don't read anything if the file doesn't exist
      if SCR.Read(path(".target.size"), "/etc/install.inf") == -1
        Builtins.y2error("Reading install.inf, but file doesn't exist!!!")
        return
      end
      entries = SCR.Dir(path(".etc.install_inf"))
      if entries == nil
        Builtins.y2error("install.inf is empty")
        return
      end
      Builtins.foreach(entries) do |e|
        val = Convert.to_string(
          SCR.Read(Builtins.add(path(".etc.install_inf"), e))
        )
        Ops.set(@install_inf, e, val)
      end

      nil
    end

    def ResetInstallInf
      @install_inf = nil
      nil
    end

    def InstallInf(key)
      ReadInstallInf()
      @install_inf[key]
    end

    def keys
      ReadInstallInf()
      @install_inf.keys
    end

    # installation mode wrappers

    def manual
      return @_manual if @_manual != nil
      @_manual = InstallInf("Manual") == "1"
      if !@_manual
        tmp = Convert.to_string(
          SCR.Read(path(".target.string"), "/proc/cmdline")
        )
        if tmp != nil &&
            Builtins.contains(Builtins.splitstring(tmp, " \n"), "manual")
          @_manual = true
        end
      end
      @_manual
    end

    # running via serial console
    def serial_console
      InstallInf("Console") != nil
    end

    # braille mode ?
    def braille
      InstallInf("Braille") != nil
    end

    # vnc mode ?
    def vnc
      InstallInf("VNC") == "1"
    end
    # remote X mode ?
    def display_ip
      InstallInf("Display_IP") != nil
    end

    # ssh mode ?
    # if booted with 'vnc=1 usessh=1', keep vnc mode, but start sshd
    # if booted with 'display_ip=1.2.3.4 usessh=1', keep remote X mode, but start sshd
    # this has to be checked by the caller, not here
    def usessh
      InstallInf("UseSSH") == "1"
    end

    # Returns if iSCSI has been requested in Linuxrc.
    def useiscsi
      InstallInf("WithiSCSI") == "1"
    end

    # we're running in textmode (-> UI::GetDisplayInfo())
    def text
      InstallInf("Textmode") == "1"
    end

    # end of install.inf reading routines

    # Write /etc/yast.inf during installation
    # @param [Hash{String => String}] linuxrc	map of key value pairs for /etc/yast.inf
    # @return [void]
    def WriteYaSTInf(linuxrc)
      linuxrc = deep_copy(linuxrc)
      yast_inf = ""
      Builtins.foreach(linuxrc) do |ykey, yvalue|
        yast_inf = Ops.add(
          Ops.add(Ops.add(Ops.add(yast_inf, ykey), ": "), yvalue),
          "\n"
        )
      end
      Builtins.y2milestone("WriteYaSTInf(%1) = %2", linuxrc, yast_inf)

      WFM.Write(path(".local.string"), "/etc/yast.inf", yast_inf) if !Mode.test
      nil
    end

    # Copy /etc/install.inf into built system so that the
    # second phase of the installation can find it.
    # @param root mount point of system
    # @return boolean true on success
    def SaveInstallInf(root)
      if Stage.initial && !Mode.test
        inst_if_file = "/etc/install.inf"

        if root != nil && root != "" && root != "/"
          if WFM.Read(path(".local.size"), inst_if_file) != -1
            Builtins.y2milestone("Copying %1 to %2", inst_if_file, root)
            if Convert.to_integer(
                WFM.Execute(
                  path(".local.bash"),
                  Builtins.sformat(
                    "grep -vi '^Sourcemounted' '%1' > %2/%1; chmod 0600 %2/%1",
                    inst_if_file,
                    root
                  )
                )
              ) != 0
              Builtins.y2error(
                "Cannot SaveInstallInf %1 to %2",
                inst_if_file,
                root
              )
            end
          else
            Builtins.y2error(
              "Can't SaveInstallInf, file %1 doesn't exist",
              inst_if_file
            )
          end
        else
          Builtins.y2error("Can't SaveInstallInf, root is %1", root)
        end

        # just for debug so we can see the original install.inf later
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add("/bin/cp /etc/install.inf ", root),
            "/var/lib/YaST2/install.inf"
          )
        )
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add("/bin/chmod 0600 ", root),
            "/var/lib/YaST2/install.inf"
          )
        )
      end
      true
    end

    publish :function => :ResetInstallInf, :type => "void ()"
    publish :function => :InstallInf, :type => "string (string)"
    publish :function => :manual, :type => "boolean ()"
    publish :function => :serial_console, :type => "boolean ()"
    publish :function => :braille, :type => "boolean ()"
    publish :function => :vnc, :type => "boolean ()"
    publish :function => :display_ip, :type => "boolean ()"
    publish :function => :usessh, :type => "boolean ()"
    publish :function => :useiscsi, :type => "boolean ()"
    publish :function => :text, :type => "boolean ()"
    publish :function => :WriteYaSTInf, :type => "void (map <string, string>)"
    publish :function => :SaveInstallInf, :type => "boolean (string)"
    publish :function => :keys, :type => "list <string> ()"
  end

  Linuxrc = LinuxrcClass.new
  Linuxrc.main
end
