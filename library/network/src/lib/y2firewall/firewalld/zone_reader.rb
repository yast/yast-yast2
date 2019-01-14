# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC
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
require "y2firewall/firewalld/zone"

module Y2Firewall
  class Firewalld
    # Class to help parsing firewall-cmd --list-all-zones output
    class ZoneReader
      include Yast::Logger

      # @return [Array<String] configured zone names
      attr_accessor :zone_names
      # @return [Hash<String,Hash>] stores the parsed configuration for eac
      #   zone indexed by its name
      attr_accessor :zone_entries
      # @return [String] zones definition to be parsed for initializing the
      #   zone objects
      attr_accessor :zones_definition

      BOOLEAN_ATTRIBUTES = ["icmp-block-inversion", "masquerade"].freeze

      # Constructor
      #
      # @param zone_names [Array<String>] zone names
      # @param zones_definition [String] text with the complete definition of
      #   existing zones.
      def initialize(zone_names, zones_definition)
        @zone_names = zone_names
        @zones_definition = zones_definition
        @zone_entries = {}
      end

      # It reads the zone definition instantiating the defined zones and
      # settings their attributes.
      #
      # @return [Array<Y2Firewall::Firewalld::Zone>]
      def read
        return [] if !@zone_names || @zone_names.empty?
        parse_zones
        initialize_zones
      end

    private

      # Iterates over the zones definition filling the zone entries with the
      # parsed information of each zone
      def parse_zones
        current_zone = nil
        current_attribute = nil
        zones_definition.each_with_object(zone_entries) do |line, entries|
          next if line.lstrip.empty?
          # If  the entry looks like a zone name
          if line.start_with?(/\w/)
            current_zone = current_zone_from(line)
            next
          end

          next unless current_zone

          attribute, value = line.split(":\s")
          if attribute && attribute.start_with?(/\s\s\w/)
            current_attribute = attribute.lstrip.tr("-", "_")
            entries[current_zone] ||= {}
            entries[current_zone][current_attribute] ||= [value.to_s]
          elsif current_attribute
            entries[current_zone][current_attribute] ||= []
            entries[current_zone][current_attribute] << line.lstrip
          end
        end
      end

      def current_zone_from(line)
        attribute, _value = line.split(/\s*\(active\)\s*$/)
        zone_names.include?(attribute) ? attribute : nil
      end

      ATTRIBUTE_MAPPING = { "summary" => "short" }.freeze
      # Iterates over the zone entries instantiating a zone object per each of
      # the entries and returning an array with all of them.
      #
      # @return [Array<Y2Firewall::Firewalld::Zone] the list of zones obtained
      #   from the parsed definition
      def initialize_zones
        zone_entries.each_with_object([]) do |(name, config), zones|
          zone = Zone.new(name: name)
          zones << zone

          config.each do |attribute, entries|
            attribute = ATTRIBUTE_MAPPING[attribute] if ATTRIBUTE_MAPPING[attribute]
            next unless zone.respond_to?("#{attribute}=")

            value = entries.first.to_s

            if BOOLEAN_ATTRIBUTES.include?(attribute)
              zone.public_send("#{attribute}=", value == "yes" ? true : false)
            elsif zone.attributes.include?(attribute.to_sym)
              zone.public_send("#{attribute}=", value)
            else
              zone.public_send("#{attribute}=", value.split)
            end
          end

          zone.untouched!
        end
      end
    end
  end
end
