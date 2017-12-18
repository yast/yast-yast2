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
require "y2firewall/firewalld/relations"

module Y2Firewall
  class Firewalld
    # Class to work with Firewalld zones
    class Zone
      extend Relations
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

      has_many :services, :interfaces, :zones, :protocols, :ports

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

      def service_open?(name)
        services.include?(name)
      end

      def masquerade?
        @masquerade
      end

    private

      def firewalld
        Y2Firewall::Firewalld.instance
      end

      def api
        @api ||= firewalld.api
      end
    end
  end
end
