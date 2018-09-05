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
require "y2firewall/firewalld/service"
require "y2firewall/firewalld/zone"
require "y2firewall/firewalld/zone_parser"
require "y2firewall/firewalld/service_parser"
require "singleton"

Yast.import "PackageSystem"

module Y2Firewall
  # Main class to interact with Firewalld
  #
  # @example Enable the cluster service into the external zone
  #
  #   require "y2firewall/firewalld"
  #
  #   f = Y2Firewall::Firewalld.instance
  #   f.read
  #   external = f.find_zone("external")
  #   external.services #=> ["ssh", "dns", "samba-client"]
  #   external.add_service("cluster")
  #   f.write
  #
  #
  class Firewalld
    include Singleton
    include Yast::Logger
    extend Forwardable

    attr_writer :api
    # @return [Array<Y2Firewall::Firewalld::Zone>] firewalld zones
    attr_accessor :zones
    # @return [Array<String>] current zone names.
    attr_accessor :current_zone_names
    # @return [Array<String>] current service names.
    attr_accessor :current_service_names
    # @return [Array<Y2Firewall::Firewalld::Service>] firewalld services. To
    #   avoid performance problems it is empty by default and the services are
    #   added when needed by the find_service method.
    attr_accessor :services
    # @return [String] Type of log denied packets (reject & drop rules).
    #   Possible values are: all, unicast, broadcast, multicast and off
    attr_accessor :log_denied_packets
    # @return [String] firewalld default zone name
    attr_accessor :default_zone

    PACKAGE = "firewalld".freeze
    SERVICE = "firewalld".freeze

    def_delegators :api, :enable!, :disable!, :reload, :running?

    # Constructor
    def initialize
      @current_zone_names = []
      @current_service_names = []
      @zones = []
      @services = []
      @read = false
    end

    # Read the current firewalld configuration initializing the zones and other
    # attributes as logging.
    #
    # @return [Boolean] true
    def read
      return false unless installed?
      @zones = zone_parser.parse
      @current_zone_names = api.zones
      @current_service_names = api.services
      @log_denied_packets = api.log_denied_packets
      @default_zone       = api.default_zone
      # The list of services is not read or initialized because takes time and
      # affects to the performance and also the services are rarely touched.
      @read = true
    end

    # Given a zone name it will add a new Zone to the current list of defined
    # ones just in case it does not exist yet.
    #
    # @param name [String] zone name
    # @return [Boolean] true if the new zone was added; false in case the zone
    #   was alredy defined
    def add_zone(name)
      return false if find_zone(name)
      zones << Y2Firewall::Firewalld::Zone.new(name: name)
      true
    end

    # Remove the given zone from the list of zones
    #
    # @param name [String] zone name
    # @return [Boolean] true if it was removed; false otherwise
    def remove_zone(name)
      removed = zones.reject! { |z| z.name == name }
      !removed.nil?
    end

    # Return from the zones list the one which matches the given name
    #
    # @param name [String] the zone name
    # @return [Y2Firewall::Firewalld::Zone, nil] the firewalld zone with the
    #   given name
    def find_zone(name)
      zones.find { |z| z.name == name }
    end

    # Return from the services list the one which matches the given name
    #
    # @param name [String] the service name
    # @return [Y2Firewall::Firewalld::Service] the firewalld service with
    #   the given name
    def find_service(name)
      services.find { |s| s.name == name } || read_service(name)
    end

    # It reads the configuration of the given service or create it from scratch
    # if not exist. After read adds it to the list of touched services.
    #
    # @param name [String] the service name
    # @return [Y2Firewall::Firewalld::Service] the recently added service
    def read_service(name)
      raise(Service::NotFound, name) unless installed?
      service = service_parser.parse(name)
      services << service
      service
    end

    # Return true if the logging config or any of the zones where modified
    # since read
    #
    # @return [Boolean] true if the config was modified; false otherwise
    def modified?
      default_zone != api.default_zone ||
        log_denied_packets != api.log_denied_packets ||
        zones_modified?
    end

    # Apply the changes to the modified zones and sets the logging option
    def write
      write_only && reload
    end

    # Apply the changes to the modified zones and sets the logging option
    def write_only
      return false unless installed?
      read unless read?
      apply_zones_changes!
      api.log_denied_packets = log_denied_packets if log_denied_packets != api.log_denied_packets
      api.default_zone       = default_zone if default_zone != api.default_zone
      true
    end

    # Apply the changes done in each of the modified zones. It will create or
    # delete all the new or removed zones depending on each case.
    def apply_zones_changes!
      zones.each do |zone|
        api.create_zone(zone.name) unless current_zone_names.include?(zone.name)
        zone.apply_changes! if zone.modified?
      end
      current_zone_names.each do |name|
        api.delete_zone(name) if !zones.any? { |z| z.name == name }
      end
    end

    # Return whether the current zones have been modified or not
    #
    # @return [Boolean] true if some zone have changed; false otherwise
    def zones_modified?
      (current_zone_names.sort != zones.map(&:name).sort) || zones.any?(&:modified?)
    end

    # Return a map with current firewalld settings.
    #
    # @return [Hash] dump firewalld settings
    def export
      return {} unless installed?
      {
        "enable_firewall"    => enabled?,
        "start_firewall"     => running?,
        "default_zone"       => default_zone,
        "log_denied_packets" => log_denied_packets,
        "zones"              => zones.map(&:export)
      }
    end

    # Return whether the firewalld package is installed or not
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

    # Return whether the configuration has been read
    #
    # @return [Boolean] true if the configuration has been read; false
    #   otherwise
    def read?
      @read
    end

    # Convenience method to instantiate the firewalld API
    def api
      @api ||= Api.new
    end

  private

    # Convenience method to isntantiate a new zone parser
    #
    # @return [ZoneParser]
    def zone_parser
      ZoneParser.new(api.zones, api.list_all_zones(verbose: true))
    end

    # Convenience method tosisntantiate a services parser
    #
    # @return [ServiceParser]
    def service_parser
      ServiceParser.new
    end
  end
end
