require "ostruct"

module Yast
  class SystemctlError < StandardError
    def initialize struct
      super "Systemctl command failed: #{struct}"
    end
  end

  module Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    class << self

      def execute command
        command = SYSTEMCTL + command
        result = SCR.Execute(Path.new(".target.bash_output"), command)
        OpenStruct.new(result.merge!(:command => command))
      end

      def socket_units
        sockets_from_files = list_unit_files(:type=>:socket).lines.map do |line|
          first_column(line)
        end

        sockets_from_units = list_units(:type=>:socket).lines.map do |line|
          first_column(line)
        end

        ( sockets_from_files | sockets_from_units ).compact
      end

      def service_units
        services_from_files = list_unit_files(:type=>:service).lines.map do |line|
          first_column(line)
        end

        services_from_units = list_units(:type=>:service).lines.map do |line|
          first_column(line)
        end

        ( services_from_files | services_from_units ).compact
      end

      def target_units
        targets_from_files = list_unit_files(:type=>:target).lines.map do |line|
          first_column(line)
        end

        targets_from_units = list_units(:type=>:target).lines.map do |line|
          first_column(line)
        end

        ( targets_from_files | targets_from_units ).compact
      end

      private

      def list_unit_files type: nil
        command = " list-unit-files "
        command << " --type=#{type} " if type
        execute(command).stdout
      end

      def list_units type: nil, all: true
        command = " list-units "
        command << " --all " if all
        command << " --type=#{type} " if type
        execute(command).stdout
      end

      def first_column line
        line[/\S+/]
      end
    end
  end
end
