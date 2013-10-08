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
# File:	modules/NetworkService.ycp
# Package:	Network configuration
# Summary:	Init script handling, ifup vs NetworkManager
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# This module used to switch between /etc/init.d/network providing
# LSB network.service and the NetworkManager.service (or another),
# which installs a network.service alias link.
#
# The service name installing the network.sevice is visible in the
# "Id" systemctl property:
#
#     # systemctl --no-pager -p Id show network.service
#     Id=network.service
#     # systemctl --force          enable NetworkManager.service
#     # systemctl --no-pager -p Id show network.service
#     Id=NetworkManager.service
#
# The network.service alias link obsoletes the old master switch in
# /etc/sysconfig/network/config:NETWORKMANAGER (until openSUSE-12.2).
require "yast"

module Yast
  class NetworkServiceClass < Module
    attr_reader :current_name

    BACKENDS = {
    # <internal-id>        <service name>
      :network          => "network",
      :network_manager  => "NetworkManager",
      :wicked           => "wicked"
    }

    def main
      Yast.import "Service"
      Yast.import "NetworkConfig"
      Yast.import "Popup"
      Yast.import "Mode"

      textdomain "base"

      # if false, read needs to do work
      @initialized = false

      # current network service id name
      @current_name = nil

      # the new network service id name
      @new_service_id_name = nil

      # Path to the systemctl command
      @systemctl = "/bin/systemctl"

      # Variable remembers that the question has been asked during this run already.
      # It avoids useless questions over and over again.
      @already_asked_for_NetworkManager = false
    end

    # Helper to run systemctl actions
    # @return exit code
    def RunSystemCtl(service, action)
      cmd = Builtins.sformat("%1 %2 %3.service", @systemctl, action, service)
      ret = Convert.convert(
        SCR.Execute(path(".target.bash_output"), cmd, { "TERM" => "raw" }),
        :from => "any",
        :to   => "map <string, any>"
      )
      Builtins.y2debug("RunSystemCtl: Command '%1' returned '%2'", cmd, ret)
      Ops.get_integer(ret, "exit", -1)
    end

    # Whether a network service change were requested
    # @return true when service change were requested
    def Modified
      ret = false
      Read()
      ret = true if @new_service_id_name != @current_name
      Builtins.y2debug(
        "NetworkService::Modified(%1, %2) => %3",
        @current_name,
        @new_service_id_name,
        ret
      )
      ret
    end

    # Replies with currently selected network service name
    #
    # Currently known backends:
    # - :NetworkManager - not supported by YaST
    # - :ifup - supported
    # - :wicked - supported (via its backward compatibility to
    # ifup)
    #
    def selected_name
      Read()
      return @new_service_id_name
    end

    # Checks if configuration is managed by NetworkManager
    #
    # @return true  when the network is managed by an external tool, 
    #               like NetworkManager, false otherwise
    def controlled_by_network_manager
      selected_name == :network_manager
    end

    def controlled_by_netconfig
      selected_name == :network
    end

    def controlled_by_wicked
      selected_name == :wicked
    end

    def use_network_manager
      Read()
      @new_service_id_name = :network_manager

      nil
    end

    def use_netconfig
      Read()
      @new_service_id_name = :network

      nil
    end

    def use_wicked
      Read()
      @new_service_id_name = :wicked

      nil
    end

    # Initialize module data
    def Read
      if !@initialized
        case Service.GetServiceId("network")
          when "network"
            @current_name = :network
          when "NetworkManager"
            @current_name = :network_manager
          when "wicked"
            @current_name = :wicked
        end
  
        @new_service_id_name = @current_name

        nm = @new_service_id_name == :network_manager
        Builtins.y2milestone("NetworkManager: %1", nm)
      end
      @initialized = true

      nil
    end

    # Enables and disables the appropriate services.
    def EnableDisable
      # Workaround for bug #61055:
      Builtins.y2milestone("Enabling service %1", "network")
      cmd = "cd /; /sbin/insserv -d /etc/init.d/network"
      SCR.Execute(path(".target.bash"), cmd)

      nil
    end

    # Run /etc/init.d script with specified action
    # @param script name of the init script
    # @param action the action to use
    # @return true, when the script exits with 0
    def RunScript(script, action)
      return true if script == ""
      Builtins.y2milestone("rc%1 %2", script, action)
      # Workaround for bug #61055:
      cmd = Builtins.sformat("cd /; /etc/init.d/%1 %2", script, action)
      SCR.Execute(path(".target.bash"), cmd) == 0
    end

    # Helper to apply a change of the network service
    def EnableDisableNow
      if Modified()
        # Stop should be called before, but when the service
        # were not correctly started until now, stop may have
        # no effect.
        # So let's kill all processes in the network service
        # cgroup to make sure e.g. dhcp clients are stopped.
        @initialized = false
        RunSystemCtl( BACKENDS[ @current_name], "kill")

        case @new_service_id_name
          when :network_manager
            RunSystemCtl( BACKENDS[ @new_service_id_name], "--force enable")
          when :wicked
            RunSystemCtl( BACKENDS[ @new_service_id_name], "--force enable")
          when :network
            RunSystemCtl( BACKENDS[ @current_name], "disable")
        end

        Read()
      end

      nil
    end

    # Reports if network service is active or not.
    # It does not report if network is connected.
    # @return true when network service is active
    def IsActive
      RunSystemCtl("network", "is-active") == 0
    end

    # Reload or restars the network service.
    def ReloadOrRestart
      if IsActive()
        if Modified()
          # reload is not sufficient
          RunSystemCtl("network", "stop")
          EnableDisableNow()
          RunSystemCtl("network", "start")
        else
          # reload may be unsupported
          RunSystemCtl("network", "reload-or-try-restart")
        end
      else
        # always stop, it does not hurt if the net was stopped.
        RunSystemCtl("network", "stop")
        EnableDisableNow()
        RunSystemCtl("network", "start")
      end

      nil
    end

    # Restarts the network service
    def Restart
      RunSystemCtl("network", "stop")
      EnableDisableNow()
      RunSystemCtl("network", "start")

      nil
    end

    # This is an old, confusing name for ReloadOrRestart() now
    def StartStop
      ReloadOrRestart()

      nil
    end

    # Opens up a continue/cancel confirmation popup
    # in the case when NetworkManager is enabled.
    # User is informed that continuing the configuration
    # may produce undefined results.
    # If NetworkManager is not used, silently returns true.
    #
    # @return [Boolean] continue
    def ConfirmNetworkManager
      if !@already_asked_for_NetworkManager && controlled_by_NetworkManager
        # TRANSLATORS: pop-up question when reading the service configuration
        cont = Popup.ContinueCancel(
          _(
            "Your network interfaces are currently controlled by NetworkManager\n" +
              "but the service to configure might not work well with it.\n" +
              "\n" +
              "Really continue?"
          )
        )
        Builtins.y2milestone(
          "Network is controlled by NetworkManager, user decided %1...",
          cont ? "to continue" : "not to continue"
        )
        @already_asked_for_NetworkManager = true

        return cont
      else
        return true
      end
    end


    # test for IPv4
    def isNetworkRunning
      net = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          "ip addr|grep -v '127.0.0\\|inet6'|grep -c inet"
        )
      )
      if net == 0
        Builtins.y2milestone("Network is running ...")
        return true
      else
        Builtins.y2milestone("Network is not running ...")
        return false
      end
    end
    # test for IPv6
    def isNetworkv6Running
      net = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          "ip addr|grep -v 'inet6 ::1\\|inet6 fe80'|grep -c inet6"
        )
      )
      if net == 0
        Builtins.y2milestone("Network is running ...")
        return true
      else
        Builtins.y2milestone("Network is not running ...")
        return false
      end
    end

    # If there is network running, return true.
    # Otherwise show error popup depending on Mode and return false
    # @return true if network running
    def RunningNetworkPopup
      Builtins.y2internal("RunningNetworkPopup %1", isNetworkRunning)
      if isNetworkRunning
        return true
      else
        error_text = Builtins.sformat(
          "%1\n%2 %3",
          _("No running network detected."),
          Mode.installation ?
            _("Restart installation and configure network in Linuxrc") :
            _(
              "Configure network with YaST or Network Manager plug-in\nand start this module again"
            ),
          _("or continue without network.")
        )
        Popup.ContinueCancel(error_text)
        Builtins.y2error("Network not runing!")
        return false
      end
    end

    publish :function => :Read, :type => "void ()"
    publish :function => :Modified, :type => "boolean ()"
    publish :function => :current_name, :type => "string ()"
    publish :function => :controlled_by_network_manager, :type => "boolean ()"
    publish :function => :controlled_by_netconfig, :type => "boolean ()"
    publish :function => :controlled_by_wicked, :type => "boolean ()"
    publish :function => :use_network_manager, :type => "void ()"
    publish :function => :use_netconfig, :type => "void ()"
    publish :function => :use_wicked, :type => "void ()"
    publish :function => :EnableDisable, :type => "void ()"
    publish :function => :IsActive, :type => "boolean ()"
    publish :function => :ReloadOrRestart, :type => "void ()"
    publish :function => :Restart, :type => "void ()"
    publish :function => :StartStop, :type => "void ()"
    publish :function => :ConfirmNetworkManager, :type => "boolean ()"
    publish :function => :isNetworkRunning, :type => "boolean ()"
    publish :function => :isNetworkv6Running, :type => "boolean ()"
    publish :function => :RunningNetworkPopup, :type => "boolean ()"
  end

  NetworkService = NetworkServiceClass.new
  NetworkService.main
end
