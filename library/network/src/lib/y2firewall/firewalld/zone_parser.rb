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
require "y2firewall/firewalld/zone"

module Y2Firewall
  class Firewalld
    # Class to help parsing firewall-cmd --list_all_zones output
    class ZoneParser
      include Yast::Logger

      attr_accessor :zone_names, :zone_entries, :zones_definition

      BOOLEAN_ATTRIBUTES = ["icmp-block-inversion", "masquerade"].freeze
      MULTIPLE_ENTRIES = ["rich_rules", "forward_ports"].freeze

      # Constructor
      #
      # @param zone_names [Array<String>] zone names
      # @param zones_definition [String] text with the complete definition of
      # existing zones.
      def initialize(zone_names, zones_definition)
        @zone_names = zone_names
        @zones_definition = zones_definition
        @zone_entries = {}
      end

      # It parses the zone definition instantiating the defined zones and
      # settings their attributes.
      #
      # @return [Array<Y2Firewall::Firewalld::Zone>]
      def parse
        return [] if !@zone_names || @zone_names.empty?
        parse_zones
        initialize_zones
      end

    private

      def initialize_zones
        zones = []
        zone_entries.each do |name, config|
          zone = Zone.new(name: name)
          zones << zone

          config.each do |attribute, entries|
            attribute = "short" if attribute == "summary"
            attribute = "rich_rules" if attribute == "rich rules"
            next unless zone.respond_to?("#{attribute}=")

            value = MULTIPLE_ENTRIES.include?(attribute) ? entries.reject(&:empty?) : entries.first.to_s

            if BOOLEAN_ATTRIBUTES.include?(attribute)
              zone.public_send("#{attribute}=", value == "yes" ? true : false)
            elsif MULTIPLE_ENTRIES.include?(attribute)
              zone.public_send("#{attribute}=", value)
            elsif zone.attributes.include?(attribute.to_sym)
              zone.public_send("#{attribute}=", value)
            else
              zone.public_send("#{attribute}=", value.split)
            end
          end

          zone.untouched!
        end

        zones
      end

      def parse_zones
        current_zone = nil
        current_attribute = nil
        zones_definition.each do |line|
          next if line.lstrip.empty?
          # If  the entry looks like a zone name
          if line.start_with?(/\w/)
            attribute, _value = line.split(/\s*\(active\)\s*$/)
            attribute = nil unless zone_names.include?(attribute)
            current_zone = attribute
            next
          end

          next unless current_zone

          attribute, value = line.split(":\s")
          if attribute && attribute.start_with?(/\s\s\w/)
            current_attribute = attribute.lstrip.tr("-", "_")
            zone_entries[current_zone] ||= {}
            zone_entries[current_zone][current_attribute] ||= [value.to_s]
          elsif current_attribute
            zone_entries[current_zone][current_attribute] ||= []
            zone_entries[current_zone][current_attribute] << line.lstrip
          end
        end

        true
      end
    end
  end
end
