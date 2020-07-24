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
require "y2firewall/firewalld/relations"
require "y2firewall/firewalld/service"
require "y2firewall/firewalld/zone"
require "y2firewall/firewalld/zone_reader"
require "y2firewall/firewalld/service_reader"
require "yast2/system_service"
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
    extend Relations

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

    PACKAGE = "firewalld".freeze
    SERVICE = "firewalld".freeze
    DEFAULT_ZONE = "public".freeze
    DEFAULT_LOG = "off".freeze
    DEFAULTS_DIR = "/usr/lib/firewalld".freeze
    CUSTOM_DIR = "/etc/firewalld".freeze

    def_delegators :api, :enable!, :disable!, :reload, :running?
    has_attributes :log_denied_packets, :default_zone, cache: true

    # Constructor
    def initialize
      load_defaults
      untouched!
      @read = false
    end

    # Read the current firewalld configuration initializing the zones and other
    # attributes as logging.
    #
    # @note when a minimal read is requested it neither parses the zones
    #   definition nor initializes any single value attributes
    #
    # @param minimal [Boolean] when true does a minimal object initialization
    # @return [Boolean] true
    def read(minimal: false)
      return false unless installed?

      # Force a reset of the API instance when reading the first time (bsc#1166698)
      @api = nil

      @current_zone_names = api.zones
      @current_service_names = api.services
      if minimal
        @zones = current_zone_names.map { |n| Zone.new(name: n) }
      else
        @zones = zone_reader.read
        read_attributes
      end
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

      service = ServiceReader.new.read(name)
      services << service
      service
    end

    # Return true if the logging config or any of the zones were modified
    # since read
    #
    # @return [Boolean] true if the config was modified; false otherwise
    def modified?(*item)
      return modified.include?(item.first) if !item.empty?

      !modified.empty? || zones.any?(&:modified?)
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
      apply_attributes_changes!
      untouched!
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
        api.delete_zone(name) if zones.none? { |z| z.name == name }
      end
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
    #
    # @return [Y2Firewall::Firewalld::Api]
    def api
      @api ||= Api.new
    end

    # Convenience method to instantiate the firewalld system service
    #
    # @return [Yast2::SystemService, nil]
    def system_service
      @system_service ||= Yast2::SystemService.find(SERVICE)
    end

    # Reset all the changes done initializing the instance with the defaults
    def reset
      load_defaults
      untouched!
      @api = nil
      @read = false
    end

    # Return the item names modified from the defaults of the given resource
    #
    # @example Obtain modified zones
    #
    #   f.modified_from_default("zones") #=> ["internal", "public"]
    #
    # @param resource [String]
    # @return [Array<String>]
    def modified_from_default(resource, target_root: "/")
      return if resource.to_s.empty?

      resource_dir = File.join(target_root, CUSTOM_DIR, resource)
      return [] unless Dir.exist?(resource_dir)

      Dir.chdir(resource_dir) do
        Dir.glob("*.xml").map { |file| File.basename(file, ".xml") }
      end
    end

  private

    # Modifies the instance with default values
    def load_defaults
      @current_zone_names = []
      @current_service_names = []
      @zones = []
      @services = []
      @log_denied_packets = DEFAULT_LOG
      @default_zone = DEFAULT_ZONE
    end

    # Convenience method to instantiate a new zone reader
    #
    # @return [ZoneReader]
    def zone_reader
      ZoneReader.new(current_zone_names, api.list_all_zones(verbose: true))
    end
  end
end
