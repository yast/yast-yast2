require "ostruct"

module Yast
  module Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    FIRST_COLUMN    = /\S+/

    class << self

      def execute command
        OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), SYSTEMCTL + command))
      end

      def socket_units
        sockets_from_files = list_unit_files(:type=>:socket).lines.map do |line|
          line[FIRST_COLUMN]
        end

        sockets_from_units = list_units(:type=>:socket).lines.map do |line|
          line[FIRST_COLUMN]
        end

        ( sockets_from_files | sockets_from_units ).compact
      end

      def service_units
        services_from_files = list_unit_files(:type=>:service).lines.map do |line|
          line[FIRST_COLUMN]
        end

        services_from_units = list_units(:type=>:service).lines.map do |line|
          line[FIRST_COLUMN]
        end

        ( services_from_files | services_from_units ).compact
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
    end
  end
end
