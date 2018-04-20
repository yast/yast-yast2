# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

require "yast"
require "yast2/execute"
require "y2firewall/firewalld/api/services"
require "y2firewall/firewalld/api/zones"

Yast.import "Stage"
Yast.import "Service"
Yast.import "PackageSystem"

module Y2Firewall
  class Firewalld
    class Error < RuntimeError
    end

    # Firewalld command line API supporting two modes (:offline and :running)
    #
    # The :offline mode is useful in environments where the daemon is not running or
    # the DBUS API is not accesible, in other case the :running mode should be
    # used.
    class Api
      include Yast::Logger
      include Yast::I18n
      include Services
      include Zones
      extend Forwardable

      # Map firewalld modes with their command line tools
      COMMAND = { offline: "firewall-offline-cmd", running: "firewall-cmd" }.freeze
      # FIXME: Do not like to define twice
      PACKAGE = "firewalld".freeze

      # Determines the mode in which firewalld is running and as consequence the
      # command to be used.
      attr_accessor :mode

      # Constructor
      def initialize(mode: nil, permanent: false)
        @mode =
          if mode == :running || running?
            :running
          else
            :offline
          end
        @permanent = permanent
      end

      # Whether the mode is :offline or not
      #
      # @return [Boolean] true if current mode if :offline; false otherwise
      def offline?
        @mode == :offline
      end

      # Whether the command called to modify configuration should make the
      # changes permanent or not
      #
      # @return [Boolean]
      def permanent?
        return false if offline?

        @permanent
      end

      # Whether firewalld is running or not
      #
      # @return [Boolean] true if the state is running; false otherwise
      def running?
        return false if Yast::Stage.initial
        return false if !Yast::PackageSystem.Installed(PACKAGE)

        state == "running"
      end

      def enable!
        offline? ? run_command("--enable") : Yast::Service.Enable("firewalld")
      end

      def disable!
        offline? ? run_command("--disable") : Yast::Service.Disable("firewalld")
      end

      # @return [Boolean] The firewalld service state (exit code)
      def state
        case Yast::Execute.on_target("firewallctl", "state", allowed_exitstatus: [0, 252])
        when 0
          "running"
        when 252
          "not running"
        else
          "unknown"
        end
      end

      # Return the default zone
      #
      # @return [String] default zone
      def default_zone
        string_command("--get-default-zone")
      end

      # Set the default zone
      #
      # @param zone [String] The firewall zone
      # @return [String] default zone
      def default_zone=(zone)
        run_command("--set-default-zone=#{zone}")
      end

      # Do a reload of the firewall if running. In offline mode just return
      # true as a reload is not needed to apply the changes.
      #
      # @return [Boolean] The firewalld reload result (exit code)
      def reload
        return true if offline?
        run_command("--reload")
      end

      # Do a complete reload of the firewall if running. In offline mode just
      # return true as a reload is not needed to apply the changes
      #
      # @return [Boolean] The firewalld complete-reload result (exit code)
      def complete_reload
        return true if offline?
        run_command("--complete-reload")
      end

      # Turn the running configuration permanent. In offline mode it just
      # return true as it is already permanent.
      #
      # @return [Boolean] The firewalld complete-reload result (exit code)
      def runtime_to_permanent
        return true if offline?
        run_command("--runtime-to-permanent")
      end

      ### Logging ###

      # @param kind [String] Denied packets to log. Possible values are:
      # all, unicast, broadcast, multicast and off
      # @return [Boolean] True if desired packet type is being logged when denied
      def log_denied_packets?(kind)
        string_command("--get-log-denied").strip == kind ? true : false
      end

      # @param kind [String] Denied packets to log. Possible values are:
      # all, unicast, broadcast, multicast and off
      # @return [Boolean] True if desired packet type was set to being logged
      # when denied
      def log_denied_packets=(kind)
        run_command("--set-log-denied=#{kind}")
      end

      # @return [String] packet type which is being logged when denied
      def log_denied_packets
        string_command("--get-log-denied").strip
      end

    private

      # Command to be used depending on the current mode.
      # @return [String] command for the current mode.
      def command
        COMMAND[@mode]
      end

      # Executes the command for the current mode with the given arguments.
      #
      # @see #command
      # @see Yast::Execute
      # @param args [Array<String>] list of command optional arguments
      # @param permanent [Boolean] if true it adds the --permanent option the
      # command to be executed
      # @param allowed_exitstatus [Fixnum, .include?, nil] allowed exit codes
      # which do not cause an exception.
      # command to be executed
      def run_command(*args, permanent: false, allowed_exitstatus: nil)
        arguments = !offline? && permanent ? ["--permanent"] : []
        arguments.concat(args)
        log.info("Executing #{command} with #{arguments.inspect}")

        Yast::Execute.on_target(
          command, *arguments, stdout: :capture, allowed_exitstatus: allowed_exitstatus
        )
      end

      # Convenience method that run the command for the current mode treating
      # the output as a string and chomping it
      #
      # @see #run_command
      # @return [String] the chomped output of the run command
      # @param args [Array<String>] list of command optional arguments
      # @param permanent [Boolean] if true it adds the --permanent option the
      # command to be executed
      def string_command(*args, permanent: false)
        run_command(*args, permanent: permanent).to_s.chomp
      end

      # Convenience method which return true whether the run command for the
      # current mode return the exit status 0.
      #
      # @see #run_command
      # @return [Boolean] true if the exit status of the executed command is 0
      # @param args [Array<String>] list of command optional arguments
      def query_command(*args)
        _output, exit_status = run_command(*args, allowed_exitstatus: [0, 1])

        exit_status == 0
      end
    end
  end
end
