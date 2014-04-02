require 'yast2/systemctl'

require 'ostruct'
require 'forwardable'

module Yast
  import 'Mode'

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
      Mode.installation ? InstallationProperties.new(self) : Properties.new(self)
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
      command = "#{command_name} #{unit_name}.#{unit_type} #{options[:options]}"
      log.info "`#{Systemctl::CONTROL} #{command}`"
      Systemctl.execute(command)
    end

    private

    def run_command!
      error.clear
      command_result = yield
      error << command_result.stderr
      refresh!
      command_result.exit.zero?
    end

    class Properties < OpenStruct
      include Yast::Logger

      def initialize systemd_unit
        super()
        self[:systemd_unit] = systemd_unit
        raw_output   = load_systemd_properties
        self[:raw]   = raw_output.stdout
        self[:error] = raw_output.stderr
        self[:exit]  = raw_output.exit

        if !exit.zero? || !error.empty?
          message = "Failed to get properties for unit '#{systemd_unit.unit_name}' ; "
          message << "Command `#{raw_output.command}` returned error: #{error}"
          log.error(message)
          self[:not_found?] = true
          return
        end

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

    # systemd command `systemctl show` is not available during installation
    # and will return error "Running in chroot, ignoring request." Therefore, we must
    # avoid calling it in the installation workflow. To keep the API partially
    # consistent, this class offers a replacement for the Properties above.
    #
    # It has two goals:
    # 1. Checks for existence of the unit based on the stderr from the command
    #    `systemctl is-enabled`
    # 2. Retrieves the status enabled|disabled which is needed in the installation
    #    system. There are currently only 3 commands available for systemd in
    #    inst-sys/chroot: `systemctl enable|disable|is-enabled`. The rest will return
    #    the error message mentioned above in this comment.
    #
    # Once the inst-sys has running dbus/systemd, this class definition can be removed
    # together with the condition for Mode.installation in the SystemdUnit#show.
    class InstallationProperties < OpenStruct
      include Yast::Logger

      def initialize systemd_unit
        super()
        self[:systemd_unit] = systemd_unit
        status = get_status
        self[:raw]          = status.stdout
        self[:error]        = status.stderr
        self[:exit]         = status.exit
        self[:enabled?]     = status.exit.zero?
        self[:not_found?]   = status.stderr.empty? ? false : true
      end

      private

      def get_status
        systemd_unit.command("is-enabled")
      end
    end
  end
end
