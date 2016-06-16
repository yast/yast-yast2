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
# File:	modules/Internet.ycp
# Package:	Network configuration
# Summary:	Internet connection and YOU during the installation
# Authors:	Michal Svec <msvec@suse.cz>
#		Arvin Schnell <arvin@suse.de>
#
# $Id$
require "yast"

module Yast
  class InternetClass < Module
    def main
      Yast.import "Map"
      Yast.import "NetworkService"
      Yast.import "Service"

      # Flag to remember if user wants to run internet test
      @do_test = true

      # Flag to remember if user wants to run suse register
      @suse_register = true

      # Flag to remember if you should be started
      @do_you = false

      # Flag to remember status of internet test:
      # nil   - skipped
      # true  - passed
      # false - failed
      @test = false

      # cache for GetDevices
      @devices = nil

      # Values for selected connection.
      @device = ""
      @type = ""
      @logfile = ""
      @provider = ""
      @password = ""
      @demand = false
      @askpassword = nil
      @capi_adsl = false
      @capi_isdn = false
    end

    # Reset values.
    def Reset
      @device = ""
      @type = ""
      @logfile = ""
      @provider = ""
      @password = ""
      @demand = false
      @askpassword = nil
      @capi_adsl = false
      @capi_isdn = false

      nil
    end

    # Used if NetworkInterfaces cannot find anything (usually because NM runs)
    # Calls ip
    # @return eg. ["eth0", "eth1"]
    def GetDevices
      if @devices.nil?
        command = "ip -oneline link list | sed -e 's/^[0-9]*: \\([^:]*\\).*/\\1/' | grep -v 'lo\\|sit0'"
        out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
        @devices = Builtins.filter(
          Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
        ) { |i| i != "" }
        @devices = Builtins.filter(@devices) { |i| i != "lo" && i != "sit0" }
      end
      deep_copy(@devices)
    end

    # Start the fastest interface
    # @param [String] log file for the commands output
    # @return true if successful started
    def Start(log)
      if @type == "dsl" && @capi_adsl || @type == "isdn"
        status = Service.Status("isdn")
        Builtins.y2milestone("We need ISDN service, status: %1", status)
        if status != 0
          if !Service.Start("isdn")
            Builtins.y2error("start failed")
            return false
          end
        end
      end

      cmd = Ops.add("/sbin/ifup ", @device)
      if NetworkService.IsManaged
        d_nm = "org.freedesktop.NetworkManager"
        s_nm = "/org/freedesktop/NetworkManager"
        # dbus-send [options] object interface.method arguments...
        cmd = Builtins.sformat(
          "dbus-send --system --dest=%1 %2 %1.setActiveDevice objpath:'%2/Devices/%3'",
          d_nm,
          s_nm,
          @device
        )
      end

      cmd = Ops.add(Ops.add(Ops.add(cmd, "> "), log), " 2>&1") if log != ""

      ret = if @askpassword == true
              SCR.Execute(path(".target.bash_input"), cmd, @password)
            else
              SCR.Execute(path(".target.bash"), cmd)
      end
      if ret != 0
        Builtins.y2error(
          "%1",
          NetworkService.IsManaged ? "NM.setActiveDevice failed" : "ifup failed"
        )
        return false
      end

      if @type == "isdn" && !@capi_isdn
        if SCR.Execute(
          path(".target.bash"),
          Ops.add("/sbin/isdnctrl dial ", @device)
        ) != 0
          Builtins.y2error("isdnctrl failed")
          return false
        end
      end

      true
    end

    # Stop the fastest interface
    # @param [String] log file for the commands output
    # @return true if successful stopped
    def Stop(log)
      # should also work for NM
      cmd = Ops.add("/sbin/ifdown ", @device)
      cmd = Ops.add(Ops.add(Ops.add(cmd, "> "), log), " 2>&1") if log != ""
      ret = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))
      ret == 0
    end

    # Status of the fastest interface
    # @return true if interface is up (which is not equal to connected)
    def Status
      # Skip test in case of NM because it returns code 3 (interface under NM controll)
      if NetworkService.IsManaged
        Builtins.y2milestone(
          "Skipping interface status test because of NetworkManager"
        )
        # only check if NM has not crashed
        return SCR.Execute(path(".target.bash"), "pgrep NetworkManager") == 0
      end

      ret = Convert.to_integer(
        SCR.Execute(path(".target.bash"), Ops.add("/sbin/ifstatus ", @device))
      )
      Builtins.y2milestone("ifstatus %1: %2", @device, ret)
      ret == 0 || ret == 10
    end

    # Test if the interface is connected
    # @return true if connected
    def Connected
      if @type == "dsl" || @type == "modem" || @type == "isdn" && @capi_isdn
        tmp1 = Convert.to_string(
          SCR.Read(
            path(".target.string"),
            Ops.add(Ops.add("/var/lib/smpppd/ifcfg-", @device), ".info")
          )
        )
        tmp2 = Builtins.splitstring(tmp1, "\n")
        return Builtins.contains(tmp2, "status: connected")
      end

      if @type == "isdn" && !@capi_isdn
        return SCR.Execute(
          path(".target.bash"),
          "/usr/bin/grep -q pppd /etc/resolv.conf"
        ) == 0
      end

      # NM: we have to wait until the interface comes up (or fails)
      # - dbus message filter
      # - grep ip addr list $device
      SCR.Execute(
        path(".target.bash"),
        "ip -oneline addr list | grep 'scope global' >&2"
      ) == 0
    end

    # Set dial-on-demand
    # @param [Boolean] demand true if dial-on-demand should be set
    def SetDemand(demand)
      pp = path(".sysconfig.network.providers.v")
      pp = Builtins.add(pp, @provider)
      pp = Builtins.add(pp, "DEMAND")
      SCR.Write(pp, demand == true ? "yes" : "no")
      SCR.Write(path(".sysconfig.network.providers"), nil)

      nil
    end

    # DANGEROUS function. Searches for all standard PID files of dhcpcd,
    # then kills all dhcpcds running (first SIGHUP, then SIGKILL).
    # Works via WFM (only for local dhcpcd).
    def ShutdownAllLocalDHCPClients
      pid_directory = "/var/run/"

      dhcp_pidfiles = Convert.convert(
        WFM.Read(path(".local.dir"), pid_directory),
        from: "any",
        to:   "list <string>"
      )
      # only dhcpcd files
      dhcp_pidfiles = Builtins.filter(dhcp_pidfiles) do |one_pidfile|
        Builtins.regexpmatch(one_pidfile, "dhcpcd-.*.pid")
      end

      Builtins.y2milestone(
        "DHCPCD uses these file under %1 directory: %2",
        pid_directory,
        dhcp_pidfiles
      )

      return true if Builtins.size(dhcp_pidfiles) == 0

      Builtins.foreach(dhcp_pidfiles) do |one_pidfile|
        process_ID = Convert.to_string(
          WFM.Read(
            path(".local.string"),
            Builtins.sformat("%1%2", pid_directory, one_pidfile)
          )
        )
        Builtins.y2milestone("Killing process ID: %1", process_ID)
        # Calls a correct kill command for SIGHUP and waits
        # Then a confirmation SIGKILL is called (should be ignored because process has hopefully already ended)
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "(kill -1 %1 && sleep 1); kill -9 %1 2>/dev/null;",
            process_ID
          )
        )
      end

      true
    end

    publish variable: :do_test, type: "boolean"
    publish variable: :suse_register, type: "boolean"
    publish variable: :do_you, type: "boolean"
    publish variable: :test, type: "boolean"
    publish variable: :devices, type: "list <string>", private: true
    publish variable: :device, type: "string"
    publish variable: :type, type: "string"
    publish variable: :logfile, type: "string"
    publish variable: :provider, type: "string"
    publish variable: :password, type: "string"
    publish variable: :demand, type: "boolean"
    publish variable: :askpassword, type: "boolean"
    publish variable: :capi_adsl, type: "boolean"
    publish variable: :capi_isdn, type: "boolean"
    publish function: :Reset, type: "void ()"
    publish function: :GetDevices, type: "list <string> ()"
    publish function: :Start, type: "boolean (string)"
    publish function: :Stop, type: "boolean (string)"
    publish function: :Status, type: "boolean ()"
    publish function: :Connected, type: "boolean ()"
    publish function: :SetDemand, type: "void (boolean)"
    publish function: :ShutdownAllLocalDHCPClients, type: "boolean ()"
  end

  Internet = InternetClass.new
  Internet.main
end
