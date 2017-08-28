require "ostruct"
require "timeout"

module Yast
  # Exception when systemctl command failed
  class SystemctlError < StandardError
    # @param details [#to_s]
    def initialize(details)
      super "Systemctl command failed: #{details}"
    end
  end

  # Wrapper around `systemctl` command.
  # - uses non-interactive flags
  # - has a timeout
  module Systemctl
    include Yast::Logger

    CONTROL         = "systemctl".freeze
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password ".freeze
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 ".freeze
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS
    TIMEOUT         = 30 # seconds

    class << self
      # @param command [String]
      # @return [#command,#stdout,#stderr,#exit]
      # @raise [SystemctlError] if it times out
      def execute(command)
        log.info("systemctl #{command}")
        command = SYSTEMCTL + command
        log.debug "Executing `systemctl` command: #{command}"
        result = timeout(TIMEOUT) { SCR.Execute(Path.new(".target.bash_output"), command) }
        OpenStruct.new(result.merge!(command: command))
      rescue Timeout::Error
        raise SystemctlError, "Timeout #{TIMEOUT} seconds: #{command}"
      end

      # @return [Array<String>] like ["a.socket", "b.socket"]
      def socket_units
        sockets_from_files = list_unit_files(type: :socket).lines.map do |line|
          first_column(line)
        end

        sockets_from_units = list_units(type: :socket).lines.map do |line|
          first_column(line)
        end

        (sockets_from_files | sockets_from_units).compact
      end

      # @return [Array<String>] like ["a.service", "b.service"]
      def service_units
        services_from_files = list_unit_files(type: :service).lines.map do |line|
          first_column(line)
        end

        services_from_units = list_units(type: :service).lines.map do |line|
          first_column(line)
        end

        (services_from_files | services_from_units).compact
      end

      # @return [Array<String>] like ["a.target", "b.target"]
      def target_units
        targets_from_files = list_unit_files(type: :target).lines.map do |line|
          first_column(line)
        end

        targets_from_units = list_units(type: :target).lines.map do |line|
          first_column(line)
        end

        (targets_from_files | targets_from_units).compact
      end

    private

      def list_unit_files(type: nil)
        command = " list-unit-files "
        command << " --type=#{type} " if type
        execute(command).stdout
      end

      def list_units(type: nil, all: true)
        command = " list-units "
        command << " --all " if all
        command << " --type=#{type} " if type
        execute(command).stdout
      end

      def first_column(line)
        line[/\S+/]
      end
    end
  end
end
