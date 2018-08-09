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
      service = build(service_name, propmap)
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

      snames.zip(property_texts).each_with_object([]) do |(name, property_text), memo|
        service = Service.new(name, service_propmap, property_text)
        memo << service unless service.not_found?
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

    # Instantiate a SystemdService object based on the given name
    #
    # Use with caution as the service might exist or not. If you need to react when
    # the service does not exist, use SystemdServiceClass.find.
    #
    # @param service_name [String] "foo" or "foo.service"
    # @param propmap [SystemdUnit::PropMap]
    # @return [Service] System service with the given name
    def build(service_name, propmap = {})
      service_name += UNIT_SUFFIX unless service_name.end_with?(UNIT_SUFFIX)
      propmap = SERVICE_PROPMAP.merge(propmap)
      Service.new(service_name, propmap)
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

      def static?
        properties.static?
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
      #
      # @note The current implementation is too simplistic. At this point, checking the
      # 'Triggers' property of each socket would be a better way. However, it won't work
      # during installation as 'systemctl show' is not available.
      #
      # @return [Yast::SystemdSocketClass::Socket,nil]
      def socket
        @socket ||= Yast::SystemdSocket.find(name)
      end

      # Determines whether the service has an associated socket
      #
      # @return [Boolean] true if an associated socket exists; false otherwise.
      def socket?
        !socket.nil?
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
