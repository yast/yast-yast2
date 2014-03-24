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
# File:	modules/Service.ycp
# Package:	yast2
# Summary:	Service manipulation
# Authors:	Martin Vidner <mvidner@suse.cz>
#		Petr Blahos <pblahos@suse.cz>
#		Michal Svec <msvec@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
###

# Functions for systemd service handling used by other modules.
# This is a legacy yast module. For new code, please use SystemdService

require "yast"

module Yasj
  import "SystemdService"

  class ServiceClass < Module
    include Yast::Logger

    attr_accessor :error

    def initialize
      textdomain "base"
      @error = ""
    end

    # @deprecated Use SystemdService.find('service_name')
    # Check that a service exists.
    # If not, set error_msg.
    # @param [String] name service name without a path, eg. nfsserver
    # @return Return true if the service exists.
    def checkExists(name)
      log.warn "[DEPRECIATION] `checkExists` is deprecated; use SystemdService instead"
      !!SystemdService.find(name)
    end

    # @deprecated Not supported by systemd
    # Get service info without peeking if service runs.
    # @param [String] name name of the service
    # @return Service information or empty map ($[])
    def Info(name)
      log.warn "[DEPRECIATION] `Info` is deprecated and not supported by systemd"
      unit = SystemdService.find(name)
      return {} unless unit

      read = Convert.to_map(SCR.Read(path(".init.scripts.runlevel"), name))
      detail = Ops.get_map(read, name, {})
      read = Convert.to_map(SCR.Read(path(".init.scripts.comment"), name))
      service = Ops.get_map(read, name, {})
      Builtins.add(
        Builtins.add(service, "start", Ops.get_list(detail, "start", [])),
        "stop",
        Ops.get_list(detail, "stop", [])
      )
    end

    # Get complete systemd unit id
    # @param name name or alias of the unit
    # @return (resolved) unit Id
    def GetUnitId(unit)
      unit = SystemdService.find(unit)
      return nil unless unit
      unit.id
    end

    # Get the name from a systemd service unit id without the .service suffix
    # @param [String] name name or alias of the service
    # @return (resolved) service name without the .service suffix
    def GetServiceId(name)
      unit = SystemdService.find(name)
      return nil unless unit
      unit.id.split('.').first
    end

    # Check if service is enabled (in any runlevel)
    #
    # Forwards to chkconfig -l which decides between init and systemd
    #
    # @param [String] name service name
    # @return true if service is set to run in any runlevel
    def Enabled(name)
      unit = SystemdService.find(name)
      !!(unit && unit.enabled?)
    end

    # @deprecated Use `Active` instead
    # Get service status.
    # The status is the output from "service status".
    # It should conform to LSB. 0 means the service is running.
    # @param [String] name name of the service
    # @return init script exit status or -1 if it does not exist
    def Status(name)
      log.warn "[DEPRECIATION] `Status` is deprecated; use Active instead"
      unit = SystemdService.find(name)
      unit && unit.active? ? 0 : -1
    end

    def Active service_name
      unit = SystemdService.find(service_name)
      !!(unit && unit.active?)
    end

    # Get service info and find out whether service is running.
    # @param [String] name name of the service
    # @return service map or empty map ($[])
    def FullInfo(name)
      return {} if !checkExists(name)
      Builtins.add(Info(name), "started", Status(name))
    end

    # @deprecated Use `Disable` instead
    # Disables a given service and records errors.
    # Does not check if it exists.
    #
    # @param [String] name service name
    # @param [Boolean] force pass "--force" (workaround for #17608, #27370)
    # @return success state
    def serviceDisable(name, force)
      log.warn "[DEPRECIATION] `serviceDisable` is deprecated; use `Disable` instead"
      unit = SystemdService.find(name)
      !!(unit && unit.disable)
    end

    # @deprecated Use the specific methods: `Enable` or `Disable`
    # Adjusts runlevels in which the service runs.
    #
    # @param string service name
    # @param [String] action "disable" -- remove links, "enable" -- if there are
    #    no links, set default, otherwise do nothing, "default" -- set
    #    defaults.
    # @return [Boolean] success state
    def Adjust(name, action)
      log.warn "[DEPRECIATION] `Adjust` is deprecated; use `Enable` or `Disable` instead"
      unit = SystemdService.find(name)
      return false unless unit

      case action
      when "disable"
        unit.disable
      when "enable", "default"
        unit.enable
      else
        log.error "Unknown action '#{action}' for service '#{name}'"
        false
      end
    end

    # @deprecated Use `Enable` or `Disable` instead
    # Set service to run in selected runlevels.
    # Obsoleted - enables or disables the given service depending on the
    # list of runlevels to start. If any runlevel is present, service is
    # enabled, otherwise disabled.
    #
    # @param [String] name name of service to adjust
    # @param [Array] rl list of runlevels in which service should start
    # @return success state
    def Finetune(name, rl)
      log.warn "[DEPRECIATION] `Finetune` is deprecated; use `Enable` or `Disable` instead"
      unit = SystemdService.find(name)
      return false unless unit

      if rl.empty?
        unit.disable
      else
        log.warn "Cannot enable service '#{name}' in selected runlevels, enabling for all"
        unit.enable
      end
    end

    # @deprecated Use specific method for service configuration
    # Run init script.
    # @param [String] name init service name
    # @param [String] param init script argument
    # @return [Fixnum] exit value
    def RunInitScript(name, param)
      log.warn "[DEPRECIATION] `RunInitScript` is deprecated; use other methods directly"

      service = SystemdService.find(name)
      return -1 unless service

      case param
      when 'start'
        service.start
      when 'stop'
        service.stop
      else
        log.error "Unknown action '#{param}' for service '#{name}'"
        -1
      end
    end

    # Run init script with a time-out.
    # @param [String] name init service name
    # @param [String] param init script argument
    # @return [Fixnum] exit value
    def RunInitScriptWithTimeOut(name, param)
      Builtins.y2milestone("Running service initscript %1 %2", name, param)
      command = Builtins.sformat(
        "TERM=dumb %1 %2 %3.service",
        @invoker,
        param,
        name
      )

      # default return code
      return_code = nil

      # starting the process
      process_pid = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), command)
      )
      if process_pid == nil || Ops.less_or_equal(process_pid, 0)
        Builtins.y2error("Cannot run '%1' -> %2", command, process_pid)
        return return_code
      end
      Builtins.y2debug("Running: %1", command)

      script_out = []
      time_spent = 0
      cont_loop = true

      # while continuing is needed and while it is possible
      while cont_loop &&
          Convert.to_boolean(SCR.Read(path(".process.running"), process_pid))
        if Ops.greater_or_equal(time_spent, @script_time_out)
          Builtins.y2error(
            "Command '%1' timed-out after %2 mces",
            command,
            time_spent
          )
          cont_loop = false
        end

        # sleep a little while
        time_spent = Ops.add(time_spent, @sleep_step)
        Builtins.sleep(@sleep_step)
      end

      # fetching the return code if not timed-out
      if cont_loop
        return_code = Convert.to_integer(
          SCR.Read(path(".process.status"), process_pid)
        )
      end

      Builtins.y2milestone(
        "Time spent: %1 msecs, retcode: %2",
        time_spent,
        return_code
      )

      # killing the process (if it still runs)
      if Convert.to_boolean(SCR.Read(path(".process.running"), process_pid))
        SCR.Execute(path(".process.kill"), process_pid)
      end

      # release the process from the agent
      SCR.Execute(path(".process.release"), process_pid)

      return_code
    end

    # Run init script and also return its output (stdout and stderr merged).
    # @param [String] name init service name
    # @param [String] param init script argument
    # @return A map of $[ "stdout" : "...", "stderr" : "...", "exit" : int]
    def RunInitScriptOutput(name, param)
      env = { "TERM" => "raw" }

      # encoding problems - append .UTF-8 to LANG
      if @lang == nil
        ex = Convert.convert(
          SCR.Execute(path(".target.bash_output"), "echo -n $LANG"),
          :from => "any",
          :to   => "map <string, any>"
        )
        @lang = Ops.get_string(ex, "stdout", "")
        ll = Builtins.splitstring(@lang, ".")
        @lang = Ops.get_string(ll, 0, "")
        @lang = Ops.add(@lang, ".UTF-8") if @lang != ""
        Builtins.y2debug("LANG: %1", @lang)
      end
      env = Builtins.add(env, "LANG", @lang) if @lang != ""

      # looks like a bug in bash...
      locale_debug = ""
      # locale_debug = "; ls /nono 2>&1; /usr/bin/locale; /usr/bin/env";

      Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Ops.add(
            Builtins.sformat("%1 %2 %3.service 2>&1", @invoker, param, name),
            locale_debug
          ),
          env
        )
      )
    end

    def service_not_found service_name
      message = "Service '#{service_name}' not found"
      self.error = message
      log.error(message)
    end

    def action_failed service, action
      message = "Service::#{action} failed for service '#{service.unit_name}' ; "
      message << service.error
      self.error = message
      log.error(message)
    end

    # Enable service
    # @param [String] service service to be enabled
    # @return true if operation is  successful
    def Enable(service)
      log.info "Enabling service %1", service
      service_unit = SystemdService.find(service)

      if !service_unit
        service_not_found(service)
        return false
      end

      if !service_unit.enable
        action_failed(service_unit, __method__)
        return false
      end

      true
    end

    # Disable service
    # @param [String] service service to be disabled
    # @return true if operation is  successful
    def Disable(service)
      log.info "Disabling service %1", service
      service_unit = SystemdService.find(service)

      if !service_unit
        service_not_found(service)
        return false
      end

      if !service_unit.disable
        action_failed(service_unit, __method__)
        return false
      end

      true
    end

    # Start service
    # @param [String] service service to be started
    # @return true if operation is  successful
    def Start(service)
      log.info "Starting service %1", service
      service = SystemdService.find(service)
      !!(service && service.start)
    end

    # Restart service
    # @param [String] service service to be restarted
    # @return true if operation is  successful
    def Restart(service)
      log.info "Restarting service %1", service
      service = SystemdService.find(service)
      !!(service && service.restart)
    end

    # Reload service
    # @param [String] service service to be reloaded
    # @return true if operation is  successful
    def Reload(service)
      log.info "Reloading service %1", service
      service = SystemdService.find(service)
      !!(service && service.reload)
    end

    # Stop service
    # @param [String] service service to be stopped
    # @return true if operation is  successful
    def Stop(service)
      log.info "Stopping service %1", service
      service = SystemdService.find(service)
      !!(service && service.stop)
    end

    # Error Message
    #
    # If a Service function returns an error, this function would return
    # an error message, including insserv stderr and possibly containing
    # newlines.
    # @return error message from the last operation
    def Error
      error
    end

    # Get list of enabled services in a runlevel
    # @param [Fixnum] runlevel requested runlevel number (0-6, -1 = Single)
    # @return [Array<String>] enabled services
    def EnabledServices(runlevel)
      if Ops.less_than(runlevel, -1) || Ops.greater_than(runlevel, 6)
        Builtins.y2error("ERROR: Invalid runlevel: %1", runlevel)
        return nil
      end

      # convert the integer to a string (-1 = S)
      runlevel_str = runlevel == -1 ? "S" : Builtins.sformat("%1", runlevel)

      ret = []

      command = Builtins.sformat("ls -1 /etc/init.d/rc%1.d/", runlevel_str)
      Builtins.y2milestone("Executing: %1", command)

      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      Builtins.y2debug("Result: %1", out)

      if Ops.get_integer(out, "exit", -1) != 0
        Builtins.y2error("ERROR: %1", out)
        return nil
      end

      Builtins.foreach(
        Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
      ) do |s|
        service = Builtins.regexpsub(s, "^S[0-9]+([^0-9]+.*)", "\\1")
        ret = Builtins.add(ret, service) if service != nil
      end


      Builtins.y2milestone("Enabled services in runlevel %1: %2", runlevel, ret)

      deep_copy(ret)
    end

    # Return the first of the list of services which is available
    # (has init script) or "" if none is.
    # @param list<string> list of service names
    # @return [String] the first found service
    def Find(services)
      services = deep_copy(services)
      found_service = ""

      Builtins.foreach(services) do |service|
        if checkExists(service)
          found_service = service
          raise Break
        end
      end

      found_service
    end

    publish :function => :GetUnitId, :type => "string (string)"
    publish :function => :GetServiceId, :type => "string (string)"
    publish :function => :Enabled, :type => "boolean (string)"
    publish :function => :Info, :type => "map (string)"
    publish :function => :Status, :type => "integer (string)"
    publish :function => :FullInfo, :type => "map (string)"
    publish :function => :Adjust, :type => "boolean (string, string)"
    publish :function => :Finetune, :type => "boolean (string, list)"
    publish :function => :RunInitScript, :type => "integer (string, string)"
    publish :function => :RunInitScriptWithTimeOut, :type => "integer (string, string)"
    publish :function => :RunInitScriptOutput, :type => "map (string, string)"
    publish :function => :Enable, :type => "boolean (string)"
    publish :function => :Disable, :type => "boolean (string)"
    publish :function => :Start, :type => "boolean (string)"
    publish :function => :Restart, :type => "boolean (string)"
    publish :function => :Reload, :type => "boolean (string)"
    publish :function => :Stop, :type => "boolean (string)"
    publish :function => :Error, :type => "string ()"
    publish :function => :EnabledServices, :type => "list <string> (integer)"
    publish :function => :Find, :type => "string (list <string>)"
  end
  Service = ServiceClass.new
end
