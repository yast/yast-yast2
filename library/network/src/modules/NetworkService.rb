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
    # @current_name - current network backend identification
    # @cached_name  - the new network backend identification

    # network backend identification to service name mapping
    BACKENDS = {
      # <internal-id>        <service name>
      netconfig:       "network",
      network_manager: "NetworkManager",
      wicked:          "wicked"
    }.freeze

    # network backend identification to its rpm package name mapping
    BACKEND_PKG_NAMES = {
      # <internal-id>        <service name>
      netconfig:       "sysconfig-network",
      network_manager: "NetworkManager",
      wicked:          "wicked"
    }.freeze

    SYSTEMCTL = "/bin/systemctl".freeze

    WICKED = "/usr/sbin/wicked".freeze

    DEFAULT_BACKEND = :wicked

    include Yast::Logger

    def main
      Yast.import "SystemdService"
      Yast.import "NetworkConfig"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "PackageSystem"

      textdomain "base"

      # if false, read needs to do work
      @initialized = false

      # Variable remembers that the question has been asked during this run already.
      # It avoids useless questions over and over again.
      @already_asked_for_NetworkManager = false
    end

    # Helper to run systemctl actions
    # @return exit code
    def RunSystemCtl(service, action)
      cmd = Builtins.sformat("%1 %2 %3.service", SYSTEMCTL, action, service)
      ret = Convert.convert(
        SCR.Execute(path(".target.bash_output"), cmd, "TERM" => "raw"),
        from: "any",
        to:   "map <string, any>"
      )
      Builtins.y2debug("RunSystemCtl: Command '%1' returned '%2'", cmd, ret)
      Ops.get_integer(ret, "exit", -1)
    end

    def run_wicked(*params)
      cmd = "#{WICKED} #{params.join(" ")}"
      ret = SCR.Execute(
        path(".target.bash"),
        cmd
      )

      Builtins.y2milestone("run_wicked: #{cmd} -> #{ret}")
    end

    # Whether a network service change were requested
    # @return true when service change were requested
    def Modified
      Read()
      @cached_name != @current_name
    end

    # Checks if given network backend is available in the system
    def backend_available?(backend)
      PackageSystem.Installed(BACKEND_PKG_NAMES[backend])
    end

    alias_method :is_backend_available, :backend_available?

    # Checks if configuration is managed by NetworkManager
    #
    # @return true  when the network is managed by an external tool,
    #               like NetworkManager, false otherwise
    def network_manager?
      cached_service?(:network_manager)
    end

    alias_method :is_network_manager, :network_manager?

    def netconfig?
      cached_service?(:netconfig)
    end

    alias_method :is_netconfig, :netconfig?

    def wicked?
      cached_service?(:wicked)
    end

    alias_method :is_wicked, :wicked?

    def disabled?
      cached_service?(nil)
    end

    alias_method :is_disabled, :disabled?

    def use_network_manager
      Read()
      @cached_name = :network_manager

      nil
    end

    def use_netconfig
      Read()
      @cached_name = :netconfig

      nil
    end

    def use_wicked
      Read()
      @cached_name = :wicked

      nil
    end

    # disables network service completely
    def disable
      @cached_name = nil
      stop_service(@current_name)
      disable_service(@current_name)

      Read()
    end

    # Initialize module data
    def Read
      return if @initialized

      if Stage.initial
        @current_name = DEFAULT_BACKEND
        log.info "Running in installer/AutoYaST, use default: #{@current_name}"
      else
        service = SystemdService.find("network")
        @current_name = BACKENDS.invert[service.name] if service
      end

      @cached_name = @current_name

      log.info "Current backend: #{@current_name}"
      @initialized = true

      nil
    end

    # Helper to apply a change of the network service
    def EnableDisableNow
      return if !Modified()

      stop_service(@current_name)
      disable_service(@current_name)

      case @cached_name
      when :network_manager, :wicked
        RunSystemCtl(BACKENDS[@cached_name], "--force enable")
      when :netconfig
        RunSystemCtl(BACKENDS[@current_name], "disable")

        # Workaround for bug #61055:
        Builtins.y2milestone("Enabling service %1", "network")
        cmd = "cd /; /sbin/insserv -d /etc/init.d/network"
        SCR.Execute(path(".target.bash"), cmd)
      end

      @initialized = false
      Read()

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
      if Stage.initial
        # inst-sys is not running systemd nor sysV init, so systemctl call
        # is not available and service has to be restarted directly
        wicked_restart
      else
        systemctl_reload_restart
      end
    end

    # Restarts the network service
    def Restart
      if Stage.initial
        wicked_restart
      else
        systemctl_restart
      end

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
      if !@already_asked_for_NetworkManager && network_manager?
        # TRANSLATORS: pop-up question when reading the service configuration
        cont = Popup.ContinueCancel(
          _(
            "Your network interfaces are currently controlled by NetworkManager\n" \
              "but the service to configure might not work well with it.\n" \
              "\n" \
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

    def isNetworkRunning
      isNetworkv4Running || isNetworkv6Running
    end

    # test for IPv4
    def isNetworkv4Running
      net = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          "ip addr|grep -v '127.0.0\\|inet6'|grep -c inet"
        )
      )
      if net == 0
        Builtins.y2milestone("IPv4 network is running ...")
        return true
      else
        Builtins.y2milestone("IPv4 network is not running ...")
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
        Builtins.y2milestone("IPv6 network is running ...")
        return true
      else
        Builtins.y2milestone("IPv6 network is not running ...")
        return false
      end
    end

    # If there is network running, return true.
    # Otherwise show error popup depending on Stage and return false
    # @return true if network running
    def RunningNetworkPopup
      network_running = isNetworkRunning

      log.info "RunningNetworkPopup #{network_running}"

      if network_running
        return true
      else
        error_text = if Stage.initial
                       _(
                         "No running network detected.\n" \
                         "Restart installation and configure network in Linuxrc\n" \
                         "or continue without network."
                       )
                     else
                       _(
                         "No running network detected.\n" \
                         "Configure network with YaST or Network Manager plug-in\n" \
                         "and start this module again\n" \
                         "or continue without network."
                       )
                     end

        ret = Popup.ContinueCancel(error_text)

        log.error "Network not runing!"
        return ret
      end
    end

  private

    # Replies with currently selected network service name
    #
    # Currently known backends:
    # - :network_manager - not supported by YaST
    # - :netconfig - supported
    # - :wicked - supported (via its backward compatibility to
    # ifup)
    #
    def cached_name
      Read()
      @cached_name
    end

    # Checks if currently cached service is the given one
    def cached_service?(service)
      cached_name == service
    rescue
      Builtins.y2error("NetworkService: error when checking cached network service")
      false
    end

    # Restarts wicked backend directly
    def wicked_restart
      run_wicked("ifdown", "all")
      run_wicked("ifup", "all")
    end

    # Restarts network backend using systemctl call
    def systemctl_restart
      RunSystemCtl("network", "stop")
      EnableDisableNow()
      RunSystemCtl("network", "start")
    end

    # Restarts or reloads configuration for network backend when
    # systemctl is available
    def systemctl_reload_restart
      if IsActive()
        if Modified()
          # reload is not sufficient
          systemctl_restart
        else
          # reload may be unsupported
          RunSystemCtl("network", "reload-or-try-restart")
        end
      else
        # always stop, it does not hurt if the net was stopped.
        systemctl_restart
      end

      nil
    end

    # Stops backend network service
    def stop_service(service)
      return if !service

      if service == :wicked
        # FIXME: you really need to use 'wickedd'. Moreover kill action do not
        # kill all wickedd services - e.g. nanny, dhcp* ... stays running
        # This needs to be clarified with wicked people.
        # bnc#864619
        RunSystemCtl("wickedd", "stop")
      else
        # Stop should be called before, but when the service
        # were not correctly started until now, stop may have
        # no effect.
        # So let's kill all processes in the network service
        # cgroup to make sure e.g. dhcp clients are stopped.
        RunSystemCtl(BACKENDS[@current_name], "kill")
      end
    end

    def disable_service(service)
      RunSystemCtl(BACKENDS[service], "disable")
    end

    publish function: :Read, type: "void ()"
    publish function: :Modified, type: "boolean ()"
    publish function: :is_backend_available, type: "boolean (symbol)"
    publish function: :is_network_manager, type: "boolean ()"
    publish function: :is_netconfig, type: "boolean ()"
    publish function: :is_wicked, type: "boolean ()"
    publish function: :is_disabled, type: "boolean ()"
    publish function: :use_network_manager, type: "void ()"
    publish function: :use_netconfig, type: "void ()"
    publish function: :use_wicked, type: "void ()"
    publish function: :IsActive, type: "boolean ()"
    publish function: :ReloadOrRestart, type: "void ()"
    publish function: :Restart, type: "void ()"
    publish function: :StartStop, type: "void ()"
    publish function: :ConfirmNetworkManager, type: "boolean ()"
    publish function: :isNetworkRunning, type: "boolean ()"
    publish function: :isNetworkv4Running, type: "boolean ()"
    publish function: :isNetworkv6Running, type: "boolean ()"
    publish function: :RunningNetworkPopup, type: "boolean ()"
  end

  NetworkService = NetworkServiceClass.new
  NetworkService.main
end
