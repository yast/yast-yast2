require 'yast2/systemd_unit'

module Yast
  ###
  #  Systemd.service unit control API
  #
  #  @example How to use it in other yast libraries
  #
  #    require 'yast'
  #
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
  #
  ##

  class SystemdServiceNotFound < StandardError
    def initialize service_name
      super "Service unit '#{service_name}' not found"
    end
  end

  class SystemdServiceClass < Module
    UNIT_SUFFIX = ".service"

    def find service_name, properties={}
      service_name += UNIT_SUFFIX unless service_name.end_with?(UNIT_SUFFIX)
      service = Service.new(service_name, properties)
      return nil if service.properties.not_found?
      service
    end

    def find! service_name, properties={}
      find(service_name, properties) || raise(SystemdServiceNotFound, service_name)
    end

    def all properties={}
      services = Systemctl.service_units.map do |service_unit|
        Service.new(service_unit, properties)
      end
    end

    class Service < SystemdUnit
      include Yast::Logger

      # Available only on installation system
      START_SERVICE_INSTSYS_COMMAND = "/bin/service_start"

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
        stop
        sleep(1)
        start
      end

      private

      def installation_system?
        File.exist?(START_SERVICE_INSTSYS_COMMAND)
      end

      def run_instsys_command command
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
