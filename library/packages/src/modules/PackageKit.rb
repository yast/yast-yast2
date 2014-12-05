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
# File:	modules/PackageKit.ycp
# Package:	yast2
# Summary:	PackageKit access functions
# Authors:	Ladislav Slezak <lslezak@suse.cz>
#
# $Id:$
#
# This is a wrrapper around PackageKit DBus interface.
require "yast"

module Yast
  class PackageKitClass < Module
    include Yast::Logger

    def main

    end

    # Check whether PackageKit daemon is running
    # @return [Boolean] return true if PackageKit is currently running
    def IsRunning
      cmd = "dbus-send --system --dest=org.freedesktop.DBus --type=method_call --print-reply " +
        "--reply-timeout=200 / org.freedesktop.DBus.NameHasOwner string:org.freedesktop.PackageKit"
      log.info "Checking PackageKit status: #{cmd}"

      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      ret = false
      lines = Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")

      Builtins.foreach(lines) do |line|
        ret = true if Builtins.regexpmatch(line, "boolean.*true")
      end 


      log.info "PackageKit is running: #{ret}"

      ret
    end

    # Ask the PackageKit daemon to quit
    # If a transaction is in progress the daemon will not quit,
    # you have to check the current status using isRunning() function.
    def SuggestQuit
      cmd = "dbus-send --system --dest=org.freedesktop.PackageKit --type=method_call " +
        "/org/freedesktop/PackageKit org.freedesktop.PackageKit.SuggestDaemonQuit"
      log.info "Asking PackageKit to quit: #{cmd}"

      ret = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))

      log.error "dbus-send failed!" if ret != 0

      nil
    end

    publish :function => :IsRunning, :type => "boolean ()"
    publish :function => :SuggestQuit, :type => "void ()"
  end

  PackageKit = PackageKitClass.new
  PackageKit.main
end
