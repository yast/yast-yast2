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

    def_delegators :@properties, :id, :path,
                   :active?, :enabled?, :running?, :loaded?

    attr_reader   :unit_name, :unit_type, :input_properties, :errors, :properties

    def initialize full_unit_name, properties={}
      @unit_name, @unit_type = full_unit_name.split(".")
      raise "Missing unit type suffix" unless unit_type
      raise "Unsupported unit type '#{unit_type}'" unless SUPPORTED_TYPES.member?(unit_type)

      @errors = ""
      @input_properties = properties.merge!(DEFAULT_PROPERTIES)
      @properties = show
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

    def command command_name, options={}
      Systemctl.execute("#{command_name} #{unit_name}.#{unit_type} #{options[:options]}")
    end

    private

    def run_command!
      errors.clear
      command_result = yield
      errors << command_result.stderr
      @properties = show
      command_result.exit.zero?
    end

    class Properties < OpenStruct

      def initialize systemd_unit
        super()
        self[:systemd_unit] = systemd_unit
        raw_properties = load_systemd_properties
        self[:raw] = raw_properties.stdout
        self[:errors] = raw_properties.stderr
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
