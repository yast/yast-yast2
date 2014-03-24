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
# Flags:	Stable
#
# $Id$
#
# Functions for service (init script) handling used by other modules.
require "yast"

module Yast
  class ServiceClass < Module
    def main
      textdomain "base"

      Yast.import "FileUtils"

      #**
      # Services Manipulation

      #  * @struct service
      #  * One service is described by such map: <pre>
      #   "servicename" : $[
      #     "defstart" : [ "2", "3", "5", ], // Default-Start comment
      #     "defstop"  : [ "0", "1", "6", ], // Default-Stop  comment
      #
      #     "reqstart" : [ "$network", "portmap" ], // Required-Start comment
      #     "reqstop"  : [ "$network", "portmap" ], // Required-Stop  comment
      #
      #     "description" : "text...",       // Description comment
      #
      #     "start" : [ "3", "5", ], // which runlevels service is really started/stopped in
      #     "stop"  : [ "3", "5", ], // read from /etc/init.d/rc?.d/* links
      #
      #     "started" : 0, // return from rcservice status (integer)
      #
      #     "dirty" : false, // was the entry changed?
      #   ]</pre>

      # Program to invoke the service init scripts, or the systemd actions
      @invoker = "/bin/systemctl"

      # Unit locations for systemd
      @systemd_dirs = [
        "/usr/lib/systemd/system",
        "/run/systemd/system",
        "/etc/systemd/system"
      ]

      # Init.d scripts location
      @INITD_DIR = "/etc/init.d"

      # After a function returns an error, this holds an error message,
      # including insserv stderr and possibly containing newlines.
      #
      # Set by
      # checkExists: [Full]Info, Status, Enabled, Adjust, Finetune
      #
      # Never cleared.
      @error_msg = ""


      # Time out for background agent - init script run
      @script_time_out = 60000
      @sleep_step = 20

      @lang = nil
    end

    # Check that a service exists.
    # If not, set error_msg.
    # @param [String] name service name without a path, eg. nfsserver
    # @return Return true if the service exists.
    def checkExists(name)
      if name == nil || name == ""
        # Error message.
        # %1 is a name of an init script in /usr/lib/systemd/system,
        # eg. nfsserver
        @error_msg = Builtins.sformat(_("Empty service name: %1."), name)
        Builtins.y2error(1, @error_msg)
        return false
      end

      possible_service_locations = Builtins.add(
        # all known $service.service locations
        Builtins.maplist(@systemd_dirs) do |directory|
          Builtins.sformat("%1/%2.service", directory, name)
        end,
        # init.d fallback, see bnc#795929 comment#20
        Builtins.sformat("%1/%2", @INITD_DIR, name)
      )

      target_dir = Builtins.find(possible_service_locations) do |service_file|
        FileUtils.Exists(service_file)
      end

      if target_dir != nil
        return true
      else
        possible_locations = Builtins.add(@systemd_dirs, @INITD_DIR)
        # Error message.
        # %1 is a name of an init script in /usr/lib/systemd/system,
        # eg. nfsserver
        @error_msg = Builtins.sformat(
          _("Service %1 does not exist in %2."),
          name,
          Builtins.mergestring(possible_locations, ", ")
        )
        Builtins.y2milestone(1, @error_msg)
        return false
      end
    end

    # Get complete systemd unit id
    # @param name name or alias of the unit
    # @return (resolved) unit Id
    def GetUnitId(unit)
      cmd = Builtins.sformat("%1 --no-pager -p Id show %2", @invoker, unit)
      ret = Convert.convert(
        SCR.Execute(path(".target.bash_output"), cmd, { "TERM" => "raw" }),
        :from => "any",
        :to   => "map <string, any>"
      )
      if Ops.get_integer(ret, "exit", -1) != 0
        Builtins.y2error(
          _("Unable to query '%1' unit Id\nCommand returned: %2\n"),
          unit,
          ret
        )
        return nil
      end

      # extract first line
      _end = Builtins.findfirstof(Ops.get_string(ret, "stdout", ""), " \n")
      out = Builtins.substring(
        Ops.get_string(ret, "stdout", ""),
        0,
        _end != nil ? _end : 0
      )

      # extract key anv value
      tmp = Builtins.splitstring(out, "=")
      if Builtins.size(tmp) != 2 || Ops.get_string(tmp, 0, "") != "Id" ||
          Ops.get_string(tmp, 1, "") == ""
        Builtins.y2error(
          _("Unable to parse '%1' unit Id query output: '%2'\n"),
          unit,
          out
        )
        return nil
      end

      Ops.get_string(tmp, 1, "")
    end

    # Get the name from a systemd service unit id without the .service suffix
    # @param [String] name name or alias of the service
    # @return (resolved) service name without the .service suffix
    def GetServiceId(name)
      id = GetUnitId(Builtins.sformat("%1.service", name))
      return nil if id == nil

      # return without .service
      pos = Builtins.search(id, ".service")
      return nil if Ops.less_or_equal(pos, 0)
      Builtins.substring(id, 0, pos)
    end

    # Check if service is enabled (in any runlevel)
    #
    # Forwards to chkconfig -l which decides between init and systemd
    #
    # @param [String] name service name
    # @return true if service is set to run in any runlevel
    def Enabled(name)
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("%1 is-enabled %2.service", @invoker, name)
      ) == 0
    end

    # Get service info without peeking if service runs.
    # @param [String] name name of the service
    # @return Service information or empty map ($[])
    def Info(name)
      Builtins.y2error("### Calling Service::Info is broken with systemd! ###")
      return {} if !checkExists(name)
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

    # Get service status.
    #
    # The status is the output from "service status".
    # It should conform to LSB. 0 means the service is running.
    # @param [String] name name of the service
    # @return init script exit status or -1 if it does not exist
    def Status(name)
      Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("%1 is-active %2.service", @invoker, name),
          { "TERM" => "raw" }
        )
      )
    end

    # Get service info and find out whether service is running.
    # @param [String] name name of the service
    # @return service map or empty map ($[])
    def FullInfo(name)
      return {} if !checkExists(name)
      Builtins.add(Info(name), "started", Status(name))
    end

    # Disables a given service and records errors.
    # Does not check if it exists.
    #
    # @param [String] name service name
    # @param [Boolean] force pass "--force" (workaround for #17608, #27370)
    # @return success state
    def serviceDisable(name, force)
      cmd = Builtins.sformat(
        "%1 %2 disable %3.service",
        @invoker,
        force ? "--force" : "",
        name
      )

      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      if 0 != Ops.get_integer(ret, "exit", -1)
        # Error message.
        # %1 is a name of an init script in /etc/init.d,
        # Disabling means that the service should not start
        # in appropriate runlevels, eg. at boot time.
        # %2 is the stderr output of insserv(8)
        @error_msg = Builtins.sformat(
          _("Unable to disable service %1\nCommand '%2' returned:%3\n"),
          name,
          cmd,
          Ops.get_string(ret, "stderr", "")
        )
        # the user is two levels up
        Builtins.y2error(2, @error_msg)
        return false
      end
      true
    end

    # Adjusts runlevels in which the service runs.
    #
    # @param string service name
    # @param [String] action "disable" -- remove links, "enable" -- if there are
    #    no links, set default, otherwise do nothing, "default" -- set
    #    defaults.
    # @return [Boolean] success state
    def Adjust(name, action)
      is_enabled = Enabled(name)

      if action == "disable"
        if is_enabled
          return serviceDisable(name, false)
        else
          return true
        end
      elsif action == "default" || action == "enable"
        if action == "enable" && is_enabled
          # nothing to do
          return true
        else
          cmd = Builtins.sformat("%1 enable %2.service", @invoker, name)
          ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

          if Ops.get_integer(ret, "exit", -1) != 0
            # Error message.
            # %1 is a name of an init script in /etc/init.d,
            # Enabling means that the service should start
            # in appropriate runlevels, eg. at boot time.
            # %2 is the stderr output of insserv(8)
            @error_msg = Builtins.sformat(
              _(
                "Unable to enable service %1\n" +
                  "Command %2 returned\n" +
                  "%3"
              ),
              name,
              cmd,
              Ops.get_string(ret, "stderr", "")
            )
            Builtins.y2error(1, @error_msg)
            return false
          end
        end

        return true
      end

      # not translated
      @error_msg = Builtins.sformat("Invalid parameter: %1", action)
      Builtins.y2internal(1, @error_msg)
      false
    end

    # Set service to run in selected runlevels.
    # Obsoleted - enables or disables the given service depending on the
    # list of runlevels to start. If any runlevel is present, service is
    # enabled, otherwise disabled.
    #
    # @param [String] name name of service to adjust
    # @param [Array] rl list of runlevels in which service should start
    # @return success state
    def Finetune(name, rl)
      rl = deep_copy(rl)
      if !checkExists(name)
        Builtins.y2error("Unknown service: %1", name)
        return false
      end

      if rl != []
        Builtins.y2warning(
          "Cannot enable service %1 (just) in selected runlevels, enabling in all default ones",
          name
        )
        return Adjust(name, "enable")
      else
        return serviceDisable(name, true)
      end
    end

    # Available only in installation system
    START_SERVICE_COMMAND = "/bin/service_start"

    # Run init script.
    # @param [String] name init service name
    # @param [String] param init script argument
    # @return [Fixnum] exit value
    def RunInitScript(name, param)
      Builtins.y2milestone("Running service initscript %1 %2", name, param)

      if File.exist?(START_SERVICE_COMMAND) && param == 'start'
        command = "#{START_SERVICE_COMMAND} #{name}"
      else
        command = Builtins.sformat("%1 %2 %3.service", @invoker, param, name)
      end

      output = Convert.convert(
        SCR.Execute(path(".target.bash_output"), command, { "TERM" => "raw" }),
        :from => "any",
        :to   => "map <string, any>"
      )

      if Ops.get_integer(output, "exit", -1) != 0
        Builtins.y2error(
          "Error while running initscript %1 :\n%2",
          command,
          output
        )
      end

      Ops.get_integer(output, "exit", -1)
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

    # Enable service
    # @param [String] service service to be enabled
    # @return true if operation is  successful
    def Enable(service)
      Builtins.y2milestone("Enabling service %1", service)
      Adjust(service, "enable")
    end

    # Disable service
    # @param [String] service service to be disabled
    # @return true if operation is  successful
    def Disable(service)
      Builtins.y2milestone("Disabling service %1", service)
      Adjust(service, "disable")
    end

    # Start service
    # @param [String] service service to be started
    # @return true if operation is  successful
    def Start(service)
      Builtins.y2milestone("Starting service %1", service)
      ret = RunInitScript(service, "start")
      Builtins.y2debug("ret=%1", ret)
      ret == 0
    end

    # Restart service
    # @param [String] service service to be restarted
    # @return true if operation is  successful
    def Restart(service)
      Builtins.y2milestone("Restarting service %1", service)
      ret = RunInitScript(service, "restart")
      Builtins.y2debug("ret=%1", ret)
      ret == 0
    end

    # Reload service
    # @param [String] service service to be reloaded
    # @return true if operation is  successful
    def Reload(service)
      Builtins.y2milestone("Reloading service %1", service)
      ret = RunInitScript(service, "reload")
      Builtins.y2debug("ret=%1", ret)
      ret == 0
    end

    # Stop service
    # @param [String] service service to be stopped
    # @return true if operation is  successful
    def Stop(service)
      Builtins.y2milestone("Stopping service %1", service)
      ret = RunInitScript(service, "stop")
      Builtins.y2debug("ret=%1", ret)
      ret == 0
    end

    # Error Message
    #
    # If a Service function returns an error, this function would return
    # an error message, including insserv stderr and possibly containing
    # newlines.
    # @return error message from the last operation
    def Error
      @error_msg
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
  Service.main
end
