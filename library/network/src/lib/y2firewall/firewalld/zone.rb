# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "y2firewall/firewalld/api"

module Y2Firewall
  class Firewalld
    # Class to work with Firewalld zones
    class Zone
      include Yast::I18n
      extend Yast::I18n

      # Map of known zone names and description
      KNOWN_ZONES = {
        "block"    => N_("Block Zone"),
        "dmz"      => N_("Demilitarized Zone"),
        "drop"     => N_("Drop Zone"),
        "external" => N_("External Zone"),
        "home"     => N_("Home Zone"),
        "internal" => N_("Internal Zone"),
        "public"   => N_("Public Zone"),
        "trusted"  => N_("Trusted Zone"),
        "work"     => N_("Work Zone")
      }.freeze

      # [String] Zone name
      attr_reader   :name

      # [Array <String>] List of zone service names
      attr_accessor :services

      # [Array <String>] List of zone interface names
      attr_accessor :interfaces

      # [Array <String>] List zone opened ports
      attr_accessor :ports

      # [Array <String>] List of zone protocols
      attr_accessor :protocols

      # [Boolean] Whether masquerade is enabled or not
      attr_accessor :masquerade

      # Constructor

      def initialize(name: nil)
        @name = name || api.default_zone
      end

      def self.known_zones
        KNOWN_ZONES
      end

      # Whether the zone collection of services or interfaces has been
      # modified
      #
      # @return [Boolean] true if services or interfaces collections have been
      # modified; false otherwise
      def modified?
        return true if current_interfaces.sort != interfaces.sort
        return true if current_services.sort   != services.sort
        return true if current_protocols.sort  != protocols.sort

        current_ports.sort != ports.sort
      end

      # It reinitializes services and interfaces with the current firewalld
      # configuration.
      def discard_changes!
        @services   = current_services
        @interfaces = current_interfaces
        @ports      = current_ports
        @protocols  = current_protocols
      end

      # Applies all the changes in firewalld but do not reload it
      def apply_changes!
        remove_interfaces!
        add_interfaces!
        remove_services!
        add_services!
        remove_ports!
        add_ports!
        remove_protocols!
        add_protocols!
      end

      # Convenience method wich reload changes applied to firewalld
      def reload!
        api.reload
      end

      def read
        return unless firewalld.installed?

        ZoneParser.new(self, api.zones, api.list_all_zones)
        @interfaces = api.list_interfaces(name)
        @services   = api.list_services(name)
        @ports      = api.list_ports(name)
        @protocols  = api.list_protocols(name)
        @masquerade = api.masquerade_enabled?(name)

        true
      end

      def add_service(name)
        return services if services.include?(name)

        services << name
      end

      def remove_service(name)
        services.delete(name)

        services
      end

      def service_open?(name)
        services.include?(name)
      end

      def add_interface(name)
        interfaces << name
      end

      def remove_interface(name)
        interfaces.delete(name)
      end

      def add_port(definition)
        pots << definition
      end

      def remove_port(definition)
        pots.delete(definition)
      end

      def masquerade?
        @masquerade
      end

    private

      # Obtains the list of interfaces assigned to the zone
      #
      # @return [Array <String>] list of interface names
      def current_interfaces
        api.list_interfaces(@name)
      end

      # Obtains the list of services assigned to the zone
      #
      # @return [Array <String>] list of service names
      def current_services
        api.list_services(@name)
      end

      # Obtains the list of ports assigned to the zone
      #
      # @return [Array <String>] list of ports
      def current_ports
        api.list_ports(@name)
      end

      # Obtains the list of interfaces assigned to this zone
      #
      # @return [Array <String>] list of service names
      def current_protocols
        api.list_protocols(@name)
      end

      # Adds the given service to this zone in firewalld
      #
      # @param [String] service name
      def add_service!(service)
        api.add_service(name, service)
      end

      # Removes the given service from this firewalld zone
      #
      # @params [String] service name
      def remove_service!(service)
        api.remove_service(name, service)
      end

      # Adds the given interface to this zone in firewalld
      #
      # @params [String] interface name
      def add_interface!(interface)
        api.add_interface(name, interface)
      end

      # Removes the given interface from this firewalld zone
      #
      # @params [String] interface name
      def remove_interface!(interface)
        api.remove_interface(name, interface)
      end

      # Adds all the interfaces that were added to the zone since it was
      # initialized
      def add_interfaces!
        interfaces_to_add.map { |i| add_interface!(i) }
      end

      # Removes from firewalld all the interfaces that were removed from the
      # zone since it was initialized
      def remove_interfaces!
        interfaces_to_remove.map { |i| remove_interface!(i) }
      end

      # Adds all the services that were added to the zone since it was
      # initialized
      def add_services!
        services_to_add.map { |i| add_service!(i) }
      end

      # Removes from firewalld all the services that were removed from the
      # zone since it was initialized
      def remove_services!
        services_to_remove.map { |i| remove_service!(i) }
      end

      # Adds all the protocols that were added to the zone since it was
      # initialized
      def add_protocols!
        protocols_to_add.map { |i| add_service!(i) }
      end

      # Removes from firewalld all the protocols that were removed from the
      # zone since it was initialized
      def remove_protocols!
        protocols_to_remove.map { |i| remove_service!(i) }
      end

      # Adds all the ports that were added to the zone since it was
      # initialized
      def add_ports!
        ports_to_add.map { |i| add_service!(i) }
      end

      # Removes from firewalld all the ports that were removed from the
      # zone since it was initialized
      def remove_ports!
        ports_to_remove.map { |i| remove_service!(i) }
      end

      # Obtains all the interfaces that were removed from the zone since
      # it was initialized
      # @return [Array <String>] interface names
      def interfaces_to_remove
        current_interfaces - interfaces
      end

      # Obtains all the interfaces that were added to the zone since it was
      # initialized.
      # @return [Array <String>] interface names
      def interfaces_to_add
        interfaces - current_interfaces
      end

      # Obtains all the services that were removed from the zone since it was
      # initialized.
      #
      # @return [Array <String>] service names
      def services_to_remove
        current_services - services
      end

      # Obtains all the services that were added to the zone since it was
      # initialized.
      # @return [Array <String>] interface names
      def services_to_add
        services - current_services
      end

      # Obtains all the protocols that were removed from the zone since it was
      # initialized.
      #
      # @return [Array <String>] service names
      def protocols_to_remove
        current_protocols - protocols
      end

      # Obtains all the protocols that were added to the zone since it was
      # initialized.
      # @return [Array <String>] interface names
      def protocols_to_add
        protocols - current_protocols
      end

      # Obtains all the ports that were removed from the zone since it was
      # initialized.
      #
      # @return [Array <String>] service names
      def ports_to_remove
        current_ports - ports
      end

      # Obtains all the ports that were added to the zone since it was
      # initialized.
      # @return [Array <String>] interface names
      def ports_to_add
        ports - current_ports
      end

      def firewalld
        Y2Firewall::Firewalld.instance
      end

      def api
        @api ||= firewalld.api
      end
    end
  end
end
