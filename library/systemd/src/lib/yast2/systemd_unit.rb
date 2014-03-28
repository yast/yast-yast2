require 'yast2/systemctl'

require 'ostruct'
require 'forwardable'

module Yast

  ###
  #  Use this class always as a parent class for implementing various systemd units.
  #  Do not use it directly for add-hoc implemenation of systemd units.
  #
  #  @example Create a systemd service unit
  #
  #     class Service < Yast::SystemdUnit
  #       SUFFIX = ".service"
  #       PROPERTIES = {
  #         :before => "Before"
  #       }
  #
  #       def initialize service_name, properties={}
  #         service_name += SUFFIX unless service_name.end_with?(SUFFIX)
  #         super(service_name, PROPERTIES.merge(properties))
  #       end
  #
  #       def before
  #         properties.before.split
  #       end
  #     end
  #
  #     service = Service.new('sshd')
  #
  #     service.before # ['shutdown.target', 'multi-user.target']
  #
  ###

  class SystemdUnit
    include Yast::Logger

    SUPPORTED_TYPES  = %w( service socket target )
    SUPPORTED_STATES = %w( enabled disabled )

    DEFAULT_PROPERTIES = {
      id:              "Id",
      pid:             "MainPID",
      description:     "Description",
      load_state:      "LoadState",
      active_state:    "ActiveState",
      sub_state:       "SubState",
      unit_file_state: "UnitFileState",
      path:            "FragmentPath"
    }

    extend Forwardable

    def_delegators :@properties, :id, :path, :description, :active?, :enabled?, :loaded?

    attr_reader :name, :unit_name, :unit_type, :input_properties, :error, :properties

    def initialize full_unit_name, properties={}
      @unit_name, @unit_type = full_unit_name.split(".")
      raise "Missing unit type suffix" unless unit_type
      log.warn "Unsupported unit type '#{unit_type}'" unless SUPPORTED_TYPES.member?(unit_type)

      @input_properties = properties.merge!(DEFAULT_PROPERTIES)
      @properties = show
      @error = self.properties.error
      @name = id.to_s.split(".").first.to_s
    end

    def refresh!
      @properties = show
      @error = properties.error
      properties
    end

    def show
      Properties.new(self)
    end

    def status
      command("status", :options => "2>&1").stdout
    end

    def start
      run_command! { command("start") }
    end

    def stop
      run_command! { command("stop") }
    end

    def enable
      run_command! { command("enable") }
    end

    def disable
      run_command! { command("disable") }
    end

    def restart
      run_command! { command("restart") }
    end

    def try_restart
      run_command! { command("try-restart") }
    end

    def reload
      run_command! { command("reload") }
    end

    def reload_or_restart
      run_command! { command("reload-or-restart") }
    end

    def reload_or_try_restart
      run_command! { command("reload-or-try-restart") }
    end

    def command command_name, options={}
      Systemctl.execute("#{command_name} #{unit_name}.#{unit_type} #{options[:options]}")
    end

    private

    def run_command!
      error.clear
      command_result = yield
      error << command_result.stderr
      return false unless error.empty?

      refresh!
      command_result.exit.zero?
    end

    class Properties < OpenStruct
      include Yast::Logger

      def initialize systemd_unit
        super()
        self[:systemd_unit] = systemd_unit
        raw_output = load_systemd_properties
        self[:error] = raw_output.stderr

        if !raw_output.exit.zero?
          message = "Failed to get properties for unit '#{systemd_unit.unit_name}' ; "
          message << "Command `#{raw_output.command}` returned error: #{error}"
          log.error(message)
          self[:not_found?] = true
          return
        end

        self[:raw] = raw_output.stdout
        extract_properties
        self[:active?]    = active_state    == "active"
        self[:running?]   = sub_state       == "running"
        self[:loaded?]    = load_state      == "loaded"
        self[:not_found?] = load_state      == "not-found"
        self[:enabled?]   = unit_file_state == "enabled"
        self[:supported?] = SUPPORTED_STATES.member?(unit_file_state)
      end

      private

      def extract_properties
        systemd_unit.input_properties.each do |name, property|
          self[name] = raw[/#{property}=(.+)/, 1]
        end
      end

      def load_systemd_properties
        properties = systemd_unit.input_properties.map do |_, property_name|
          " --property=#{property_name} "
        end
        systemd_unit.command("show", :options => properties.join)
      end
    end
  end
end
