require "yast2/systemd_unit"

module Yast
  ###
  #  Systemd.socket unit control API
  #
  #  @example How to use it in other yast libraries
  #
  #    require 'yast'
  #
  #    Yast.import 'SystemdSocket'
  #
  #    ## Get a socket unit by its name
  #    ## If the socket unit can't be found, you'll get a nil object
  #
  #    socket = Yast::SystemdSocket.find('iscsid') # socket unit object
  #
  #    ## If you can't handle any nil at the place of calling,
  #    ## use the finder with exclamation mark;
  #    ## SystemdSocketNotFound exception will be raised
  #
  #    socket = Yast::SystemdSocket.find!('IcanHasCheez') # SystemdSocketNotFound: Socket unit 'IcanHasCheez' not found
  #
  #    ## Get basic unit properties
  #
  #    socket.unit_name   # 'iscsid'
  #    socket.unit_type   # 'socket'
  #    socket.id          # 'iscsid.socket'
  #    socket.path        # '/usr/lib/systemd/system/iscsid.socket' => unit file path
  #    socket.loaded?     # true if it's loaded, false otherwise
  #    socket.listening?  # true if it's listening, false otherwise
  #    socket.enabled?    # true if enabled, false otherwise
  #    socket.disabled?   # true if disabled, false otherwise
  #    socket.status      # the same string output you get with `systemctl status iscsid.socket`
  #    socket.show        # equivalent of calling `systemctl show iscsid.socket`
  #
  #    ## Socket unit file commands
  #
  #    # Unit file commands do modifications on the socket unit. Calling them triggers
  #    # socket properties reloading. In case a command fails, the error messages are available
  #    # through the method #errors as a string.
  #
  #    socket.start       # true if unit has been activated successfully
  #    socket.stop        # true if unit has been deactivated successfully
  #    socket.enable      # true if unit has been enabled successfully
  #    socket.disable     # true if unit has been disabled successfully
  #    socket.errors      # error string available if some of the actions above fails
  #
  #    ## Extended socket properties
  #
  #    # In case you need more details about the socket unit than the default ones,
  #    # you can extend the paramters when getting the socket. Those properties are
  #    # then available under the #properties instance method. To get an overview of
  #    # available socket properties, try e.g., `systemctl show iscsid.socket`
  #
  #    socket = Yast::SystemdSocket.find('iscsid', :can_start=>'CanStart', :triggers=>'Triggers')
  #    socket.properties.can_start  # 'yes'
  #    socket.properties.triggers   # 'iscsid.service'
  #
  ##

  class SystemdSocketNotFound < StandardError
    def initialize(socket_name)
      super "Socket unit '#{socket_name}' not found"
    end
  end

  class SystemdSocketClass < Module
    UNIT_SUFFIX = ".socket".freeze

    def find(socket_name, properties = {})
      socket_name += UNIT_SUFFIX unless socket_name.end_with?(UNIT_SUFFIX)
      socket = Socket.new(socket_name, properties)
      return nil if socket.properties.not_found?
      socket
    end

    def find!(socket_name, properties = {})
      find(socket_name, properties) || raise(SystemdSocketNotFound, socket_name)
    end

    def all(properties = {})
      sockets = Systemctl.socket_units.map do |socket_unit|
        Socket.new(socket_unit, properties)
      end
      sockets.select { |s| s.properties.supported? }
    end

    class Socket < SystemdUnit
      def listening?
        properties.sub_state == "listening"
      end
    end
  end
  SystemdSocket = SystemdSocketClass.new
end
