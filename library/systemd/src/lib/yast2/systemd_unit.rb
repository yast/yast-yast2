require "yast2/systemctl"

require "ostruct"
require "forwardable"

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
  class SystemdUnit
    Yast.import "Stage"
    include Yast::Logger

    SUPPORTED_TYPES  = %w( service socket target ).freeze
    SUPPORTED_STATES = %w( enabled disabled ).freeze

    DEFAULT_PROPERTIES = {
      id:              "Id",
      pid:             "MainPID",
      description:     "Description",
      load_state:      "LoadState",
      active_state:    "ActiveState",
      sub_state:       "SubState",
      unit_file_state: "UnitFileState",
      path:            "FragmentPath"
    }.freeze

    extend Forwardable

    def_delegators :@properties, :id, :path, :description, :active?, :enabled?, :loaded?

    attr_reader :name, :unit_name, :unit_type, :input_properties, :error, :properties

    def initialize(full_unit_name, properties = {})
      @unit_name, @unit_type = full_unit_name.split(".")
      raise "Missing unit type suffix" unless unit_type

      log.warn "Unsupported unit type '#{unit_type}'" unless SUPPORTED_TYPES.member?(unit_type)
      @input_properties = properties.merge!(DEFAULT_PROPERTIES)

      @properties = show
      @error = self.properties.error
      @name = id.to_s.split(".").first || unit_name
    end

    def refresh!
      @properties = show
      @error = properties.error
      properties
    end

    def show
      # Using different handler during first stage (installation, update, ...)
      Stage.initial ? InstallationProperties.new(self) : Properties.new(self)
    end

    def status
      command("status", options: "2>&1").stdout
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

    def command(command_name, options = {})
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

    # Structure holding  properties of systemd unit
    class Properties < OpenStruct
      include Yast::Logger

      def initialize(systemd_unit)
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
        self[:active?]    = active_state == "active" || active_state == "activating"
        self[:running?]   = sub_state    == "running"
        self[:loaded?]    = load_state   == "loaded"
        self[:not_found?] = load_state   == "not-found"
        self[:enabled?]   = read_enabled_state
        self[:supported?] = SUPPORTED_STATES.member?(unit_file_state)
      end

    private

      # Check the value of #unit_file_state; its value mirrors UnitFileState dbus property
      # @return [Boolean] True if enabled, False if not
      def read_enabled_state
        # If UnitFileState property is missing due to e.g. legacy sysvinit service
        # we must use a different way how to get the real status of the service
        if unit_file_state.nil?
          # Check for exit code of `systemctl is-enabled systemd_unit.name` ; additionally
          # test the stdout of the command for valid values when the service is enabled
          # http://www.freedesktop.org/software/systemd/man/systemctl.html#is-enabled%20NAME...
          status = systemd_unit.command("is-enabled")
          status.exit.zero? && state_name_enabled?(status.stdout)
        else
          state_name_enabled?(unit_file_state)
        end
      end

      # Systemd service unit can have various states like enabled, enabled-runtime,
      # linked, linked-runtime, masked, masked-runtime, static, disabled, invalid.
      # We test for the return value 'enabled' and 'enabled-runtime' to consider
      # a service as enabled.
      # @return [Boolean] True if enabled, False if not
      def state_name_enabled?(state)
        ["enabled", "enabled-runtime"].member?(state.strip)
      end

      def extract_properties
        systemd_unit.input_properties.each do |name, property|
          self[name] = raw[/#{property}=(.+)/, 1]
        end
      end

      def load_systemd_properties
        properties = systemd_unit.input_properties.map do |_, property_name|
          " --property=#{property_name} "
        end
        systemd_unit.command("show", options: properties.join)
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
    # together with the condition for Stage.initial in the SystemdUnit#show.
    class InstallationProperties < OpenStruct
      include Yast::Logger

      def initialize(systemd_unit)
        super()
        self[:systemd_unit] = systemd_unit
        self[:status]       = read_status
        self[:raw]          = status.stdout
        self[:error]        = status.stderr
        self[:exit]         = status.exit
        self[:enabled?]     = status.exit.zero?
        self[:not_found?]   = service_missing?
      end

    private

      def read_status
        systemd_unit.command("is-enabled")
      end

      # Analyze the exit code and stdout of the command `systemctl is-enabled service_name`
      # http://www.freedesktop.org/software/systemd/man/systemctl.html#is-enabled%20NAME...
      def service_missing?
        # the service exists and it's enabled
        return false if status.exit.zero?
        # the service exists and it's disabled
        return false if status.exit.nonzero? && status.stdout.match(/disabled|masked|linked/)
        # for all other cases the service does not exist
        true
      end
    end
  end
end
