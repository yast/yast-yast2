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
      include Yast::Logger

      textdomain "base"

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

      # @see Y2Firewall::Firewalld::Relations
      has_many :services, :interfaces, :protocols, :rich_rules, :sources,
        :ports, :source_ports, :forward_ports, cache: true

      # @see Y2Firewall::Firewalld::Relations
      has_attributes :name, :masquerade, :short, :description, :target, cache: true

      alias_method :masquerade?, :masquerade

      # Constructor
      #
      # If a :name is given it is used as the zone name. Otherwise, the default
      # zone name will be used as fallback.
      #
      # @param name [String] zone name
      def initialize(name: nil)
        @name = name || api.default_zone
        relations.each { |r| public_send("#{r}=", []) }
      end

      def self.known_zones
        KNOWN_ZONES
      end

      # Setter method for enabling masquerading.
      #
      # @param enable [Boolean] true for enable; false for disable
      # @return [Boolean] whether it is enabled or not
      def masquerade=(enable)
        modified!(:masquerade)
        @masquerade = enable || false
      end

      # Known full name of the known zones. Usefull when the API is not
      # accessible or when make sense to not call it directly to obtain
      # the full name.
      #
      # @return [String] zone full name
      def full_name
        self.class.known_zones[name]
      end

      # Apply all the changes in firewalld but do not reload it
      def apply_changes!
        # newly created zone
        if !api.zones.include?(name)
          log.info "adding new zone #{inspect}"
          api.create_zone(name)
        end
        return true unless modified?

        apply_relations_changes!
        apply_attributes_changes!
        if modified?(:masquerade)
          masquerade? ? api.add_masquerade(name) : api.remove_masquerade(name)
        end
        untouched!

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
        read_relations
        @masquerade = api.masquerade_enabled?(name)
        untouched!

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
        (attributes + relations)
          .each_with_object({}) do |field, profile|
            profile[field.to_s] = public_send(field) unless public_send(field).nil?
          end
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
