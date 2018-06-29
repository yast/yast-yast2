require "yast2/systemd_unit"

Yast.import "SystemdSocket"

module Yast
  class SystemdServiceNotFound < StandardError
    def initialize(service_name)
      super "Service unit '#{service_name}' not found"
    end
  end

  # Systemd.service unit control API
  #
  # @example How to use it in other yast libraries
  #    require 'yast'
  #    Yast.import 'SystemdService'
  #
  #    ## Get a service unit by its name
  #    ## If the service unit can't be found, you'll get nil
  #
  #    service = Yast::SystemdService.find('sshd') # service unit object
  #
  #    # or using the full unit id 'sshd.service'
  #
  #    service = Yast::SystemdService.find('sshd.service')
  #
  #    ## If you can't handle any nil at the place of calling,
  #    ## use the finder with exclamation mark;
  #    ## SystemdServiceNotFound exception will be raised
  #
  #    service = Yast::SystemdService.find!('IcanHasMoar') # SystemdServiceNotFound: Service unit 'IcanHasMoar' not found
  #
  #    ## Get basic unit properties
  #
  #    service.unit_name   # 'sshd'
  #    service.unit_type   # 'service'
  #    service.id          # 'sshd.service'
  #    service.description # 'OpenSSH Daemon'
  #    service.path        # '/usr/lib/systemd/system/sshd.service'
  #    service.loaded?     # true if it's loaded, false otherwise
  #    service.running?    # true if it's active and running
  #    service.enabled?    # true if enabled, false otherwise
  #    service.disabled?   # true if disabled, false otherwise
  #    service.status      # the same text output you get with `systemctl status sshd.service`
  #    service.show        # equivalent of calling `systemctl show sshd.service`
  #
  #    ## Service unit file commands
  #
  #    # Unit file commands do modifications on the service unit. Calling them triggers
  #    # service properties reloading. If a command fails, the error message is available
  #    # through the method #error as a string.
  #
  #    service.start       # true if unit has been activated successfully
  #    service.stop        # true if unit has been deactivated successfully
  #    service.enable      # true if unit has been enabled successfully
  #    service.disable     # true if unit has been disabled successfully
  #    service.error       # error string available if some of the actions above fails
  #
  #    ## Extended service properties
  #
  #    # In case you need more details about the service unit than the default ones,
  #    # you can extend the parameters for .find method. Those properties are
  #    # then available on the service unit object under the #properties instance method.
  #    # An extended property is always a string, you must convert it manually,
  #    # no automatical casting is done by yast.
  #    # To get an overview of available service properties, try e.g., `systemctl show sshd.service`
  #
  #    service = Yast::SystemdService.find('sshd', :type=>'Type')
  #    service.properties.type  # 'simple'
  class SystemdServiceClass < Module
    Yast.import "Stage"
    include Yast::Logger

    UNIT_SUFFIX = ".service".freeze
    SERVICE_PROPMAP = SystemdUnit::DEFAULT_PROPMAP.merge(triggered_by: "TriggeredBy")

    # @param service_name [String] "foo" or "foo.service"
    # @param propmap [SystemdUnit::PropMap]
    # @return [Service,nil] `nil` if not found
    def find(service_name, propmap = {})
      service_name += UNIT_SUFFIX unless service_name.end_with?(UNIT_SUFFIX)
      propmap = SERVICE_PROPMAP.merge(propmap)
      service = Service.new(service_name, propmap)
      return nil if service.properties.not_found?
      service
    end

    # @param service_name [String] "foo" or "foo.service"
    # @param propmap [SystemdUnit::PropMap]
    # @return [Service]
    # @raise [SystemdServiceNotFound]
    def find!(service_name, propmap = {})
      find(service_name, propmap) || raise(SystemdServiceNotFound, service_name)
    end

    # @param service_names [Array<String>] "foo" or "foo.service"
    # @param propmap [SystemdUnit::PropMap]
    # @return [Array<Service,nil>] `nil` if a service is not found,
    #   [] if this helper cannot be used:
    #   either we're in the inst-sys without systemctl,
    #   or it has returned fewer services than requested
    #   (and we cannot match them up)
    private def find_many_at_once(service_names, propmap = {})
      return [] if Stage.initial

      service_propmap = SERVICE_PROPMAP.merge(propmap)
      snames = service_names.map { |n| n + UNIT_SUFFIX unless n.end_with?(UNIT_SUFFIX) }
      snames_s = snames.join(" ")
      pnames_s = service_propmap.values.join(",")
      out = Systemctl.execute("show  --property=#{pnames_s} #{snames_s}")
      log.error "returned #{out.exit}, #{out.stderr}" unless out.exit.zero? && out.stderr.empty?
      property_texts = out.stdout.split("\n\n")
      return [] unless snames.size == property_texts.size

      snames.zip(property_texts).map do |service_name, property_text|
        service = Service.new(service_name, service_propmap, property_text)
        next nil if service.properties.not_found?
        service
      end
    end

    # @param service_names [Array<String>] "foo" or "foo.service"
    # @param propmap [SystemdUnit::PropMap]
    # @return [Array<Service,nil>] `nil` if not found
    def find_many(service_names, propmap = {})
      services = find_many_at_once(service_names, propmap)
      return services unless services.empty?

      log.info "Retrying one by one"
      service_names.map { |n| find(n, propmap) }
    end

    # @param propmap [SystemdUnit::PropMap]
    # @return [Array<Service>]
    def all(propmap = {})
      Systemctl.service_units.map do |service_unit|
        Service.new(service_unit, propmap)
      end
    end

    class Service < SystemdUnit
      include Yast::Logger

      # Available only on installation system
      START_SERVICE_INSTSYS_COMMAND = "/bin/service_start".freeze

      # @return [String]
      def pid
        properties.pid
      end

      def running?
        properties.running?
      end

      def start
        command = "#{START_SERVICE_INSTSYS_COMMAND} #{unit_name}"
        installation_system? ? run_instsys_command(command) : super
      end

      def stop
        command = "#{START_SERVICE_INSTSYS_COMMAND} --stop #{unit_name}"
        installation_system? ? run_instsys_command(command) : super
      end

      def restart
        # Delegate to SystemdUnit#restart if not within installation
        return super unless installation_system?

        stop
        sleep(1)
        start
      end

      # Returns socket associated with service or nil if there is no such socket
      def socket
        return @socket if @socket

        # not triggered
        socket_name = properties.triggered_by
        return unless socket_name

        socket_name = socket_name[/\S+\.socket/]
        return unless socket_name # triggered by non-socket

        @socket = Yast::SystemdSocket.find(socket_name)
      end

      alias_method :enable_service, :enable
      private :enable_service

      # Enable a service
      #
      # @param mode [Symbol] Start mode (:boot or :demand).
      # @return [Boolean] true if the service was successfully enabled; false otherwise.
      def enable
        self.start_mode = :boot
      end

      alias_method :disable_service, :disable
      private :disable_service

      # Disable a service
      #
      # If the service has an associated socket, it is disabled too.
      #
      # @return [Boolean] true if the service was successfully disabled; false otherwise.
      def disable
        self.start_mode = :manual
      end

      alias_method :enabled_on_boot?, :enabled?
      private :enabled_on_boot?

      # Determine whether the service is enabled or not
      #
      # The service can be enable to be started on boot or on demand.
      #
      # @return [Boolean] true if the service is enabled; false otherwise.
      def enabled?
        start_mode != :manual
      end

      # Determine whether the service has an associated socket
      #
      # @return [Boolean] true if an associated socket exists; false otherwise.
      def socket?
        !socket.nil?
      end

      # Return the start mode
      #
      # See {#start_modes} to find out the supported modes for a given service (usually :boot,
      # :manual and, in some cases, :demand).
      #
      # When the service (:boot) and the socket (:demand) are enabled, the start mode is translated
      # to :boot.
      #
      # @return [Symbol] Start mode (:boot, :demand, :manual)
      def start_mode
        return :boot if enabled_on_boot?
        return :demand if socket && socket.enabled?
        :manual
      end

      # Set the service start mode
      #
      # See {#start_modes} to find out the supported modes for a given service (usually :boot,
      # :manual and, in some cases, :demand).
      #
      # @see #start_modes
      def start_mode=(mode)
        if !start_modes.include?(mode)
          raise ArgumentError, "Invalid start mode: '#{mode}' for service '#{name}'"
        end

        case mode
        when :boot
          enable_service
          socket.disable
        when :demand
          disable_service
          socket.enable
        when :manual
          disable_service
          socket.disable
        end
      end

      # Return the list of supported start modes
      #
      # * :boot:   The service will be started when the system boots.
      # * :manual: The service is disabled and it will be started manually.
      # * :demand: The service will be started on demand (using a Systemd socket).
      #
      # @return [Array<Symbol>] List of supported modes.
      def start_modes
        return @start_modes if @start_modes
        @start_modes = [:boot, :manual]
        @start_modes.insert(1, :demand) if socket?
        @start_modes
      end

    private

      def installation_system?
        File.exist?(START_SERVICE_INSTSYS_COMMAND)
      end

      def run_instsys_command(command)
        log.info("Running command '#{command}'")
        error.clear
        result = OpenStruct.new(
          SCR.Execute(Path.new(".target.bash_output"), command)
        )
        error << result.stderr
        result.exit.zero?
      end
    end
  end
  SystemdService = SystemdServiceClass.new
end
