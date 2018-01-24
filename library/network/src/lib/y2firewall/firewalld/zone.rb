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
      attr_reader :name

      # @see Y2Firewall::Firewalld::Relations
      has_many :services, :interfaces, :protocols, :ports, :sources

      # [Boolean] Whether masquerade is enabled or not
      attr_reader :masquerade

      attr_accessor :modified

      alias_method :masquerade?, :masquerade

      # Constructor
      #
      # If a :name is given it is used as the zone name. Otherwise, the default
      # zone name will be used as fallback.
      #
      # @param name [String] zone name
      def initialize(name: nil)
        @name = name || api.default_zone
        @modified = []
      end

      def self.known_zones
        KNOWN_ZONES
      end

      def masquerade=(value)
        @masquerade = value

        @modified << :masquerade unless @modified.include?(:masquerade)
      end

      def full_name
        self.class.known_zones[name]
      end

      # Whether the zone have been modified or not since read
      #
      # @return [Boolean] true if it was modified; false otherwise
      def modified?
        !modified.empty?
      end

      # Apply all the changes in firewalld but do not reload it
      def apply_changes!
        return true unless modified?

        apply_all_relations_changes!
        if modified.include?(:masquerade)
          masquerade? ? api.add_masquerade(name) : api.remove_masquerade(name)
        end
        @modified = []

        true
      end

      # Convenience method wich reload changes applied to firewalld
      def reload!
        api.reload
      end

      # Read and modify the state of the object with the current firewalld
      # configuration for this zone.
      def read
        return unless firewalld.installed?

        relations.each { |r| instance_variable_set("@#{r}", public_send("current_#{r}")) }

        @masquerade = api.masquerade_enabled?(name)
        @modified = []

        true
      end

      # Return whether a service is present in the list of services or not
      #
      # @param service [String] name of the service to check
      # @return [Boolean] true if the given service name is part of services
      def service_open?(service)
        services.include?(service)
      end

      # Dump a hash with the zone configuration
      #
      # @return [Hash] zone configuration
      def export
        {
          "name"       => name,
          "interfaces" => interfaces,
          "services"   => services,
          "ports"      => ports,
          "protocols"  => protocols,
          "sources"    => sources,
          "masquerade" => masquerade
        }
      end

      # Override relation method to be more defensive. An interface can only
      # belong to one zone and the change method remove it before add.
      #
      # @param interface [String] interface name
      def add_interface!(interface)
        api.change_interface(name, interface)
      end

      # Override relation method to be more defensive. A source can only belong
      # to one zone and the change method remove it before add.
      #
      # @param source [String] source address
      def add_source!(source)
        api.change_source(name, source)
      end

    private

      # Convenience method which return an instance of Y2Firewall::Firewalld
      #
      # @return [Y2Firewall::Firewalld] a firewalld instance
      def firewalld
        Y2Firewall::Firewalld.instance
      end

      # Convenience method which return an instance of the firewalld API
      #
      # @return [Y2Firewall::Firewalld::API] a firewalld api instance
      def api
        @api ||= firewalld.api
      end
    end
  end
end
