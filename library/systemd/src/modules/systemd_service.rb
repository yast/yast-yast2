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
  #
  #    service = Yast::SystemdService.find('sshd')
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
  #    # through the method #errors as a string.
  #
  #    service.start       # true if unit has been activated successfully
  #    service.stop        # true if unit has been deactivated successfully
  #    service.enable      # true if unit has been enabled successfully
  #    service.disable     # true if unit has been disabled successfully
  #    service.errors      # error string available if some of the actions above fails
  #
  #    ## Extended service properties
  #
  #    # In case you need more details about the service unit than the default ones,
  #    # you can extend the parameters for .find method. Those properties are
  #    # then available on the service unit object under the #properties instance method.
  #    # An extended property is always a string, you must convert it manually,
  #    # not automatical casting is done by yast.
  #    # To get an overview of available service properties, try e.g., `systemctl show sshd.service`
  #
  #    service = Yast::SystemdService.find('sshd', :type=>'Type')
  #    service.properties.type  # 'simple'
  #
  ##

  class SystemdServiceClass < Module
    UNIT_SUFFIX = ".service"

    def find service_name, properties={}
      service_name << UNIT_SUFFIX unless service_name.end_with?(UNIT_SUFFIX)
      service = Service.new(service_name, properties)
      return nil if service.properties.not_found?
      service
    end

    def all properties={}
      services = Systemctl.service_units.map do |service_unit|
        Service.new(service_unit, properties)
      end
    end

    class Service < SystemdUnit
      # TODO
    end
  end
  SystemdService = SystemdServiceClass.new
end
