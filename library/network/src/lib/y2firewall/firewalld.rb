# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

require "y2firewall/firewalld/api"
require "y2firewall/firewalld/zone"
require "y2firewall/firewalld/zone_parser"
require "singleton"

Yast.import "PackageSystem"

module Y2Firewall
  # Main class to interact with Firewalld
  class Firewalld
    include Singleton
    include Yast::Logger
    extend Forwardable

    # Y2Firewall::Firewalld::Api instance
    attr_accessor :api

    # [Array <Y2Firewall::Firewalld::Zone>] firewalld zones
    attr_accessor :zones

    # [String] Type of log denied packets (reject & drop rules). Possible
    # values are: all, unicast, broadcast, multicast and off
    attr_accessor :log_denied_packets

    PACKAGE = "firewalld".freeze
    SERVICE = "firewalld".freeze

    def_delegators :@api, :enable!, :disable!, :reload, :running?

    # Constructor
    def initialize
      @api = Api.new
    end

    # Read the current firewalld configuration initializing the zones and other
    # attributes as logging.
    #
    # @return [Boolean] true
    def read
      @zones = installed? ? ZoneParser.new(api.zones, api.list_all_zones).parse : []

      @log_denied_packets = api.log_denied_packets

      true
    end

    # Return from the zones list the one which matches the given name
    #
    # @param name [String] the zone name
    # @return [Y2Firewall::Firewalld::Zone, nil] the firewalld zone with the given
    # name
    def find_zone(name)
      @zones.find { |z| z.name == name }
    end

    # Return true if the logging config or any of the zones where modified
    # since read
    #
    # @return [Boolean] true if the config was modified; false otherwise
    def modified?
      return true if @log_denied_packets != api.log_denied_packets

      @zones.any?(&:modified?)
    end

    # Apply the changes to the modified zones and sets the logging option
    def write
      @zones.map { |z| z.apply_changes! if z.modified? }

      api.log_denied_packets = log_denied_packets

      true
    end

    # Return wheter the firewalld package is installed or not
    #
    # @return [Boolean] true if it is installed; false otherwise
    def installed?
      return true if @installed

      @installed = Yast::PackageSystem.Installed(PACKAGE)
    end

    # Check whether the firewalld service is enable or not
    #
    # @return [Boolean] true if it is enable; false otherwise
    def enabled?
      return false unless installed?

      Yast::Service.Enabled(SERVICE)
    end

    # Restart the firewalld service
    #
    # @return [Boolean] true if it has been restarted; false otherwise
    def restart
      return false unless installed?

      Yast::Service.Restart(SERVICE)
    end

    # Stop the firewalld service
    #
    # @return [Boolean] true if it has been stopped; false otherwise
    def stop
      return false if !installed? || !running?

      Yast::Service.Stop(SERVICE)
    end

    # Start the firewalld service
    #
    # @return [Boolean] true if it has been started; false otherwise
    def start
      return false if !installed? || running?

      Yast::Service.Start(SERVICE)
    end
  end
end
