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
    # Class to help parsing firewall-cmd --list_all_zones output
    class ZoneParser
      include Yast::Logger

      BOOLEAN_ATTRIBUTES = ["icmp-block-inversion", "masquerade"].freeze

      # Constructor
      #
      # @param zone_names [Array<String>] zone names
      # @param zones_definition [String] text with the complete definition of
      # existing zones.
      def initialize(zone_names, zones_definition)
        @zone_names = zone_names
        @zones_definition = zones_definition
      end

      # It parses the zone definition instantiating the defined zones and
      # settings their attributes.
      #
      # @return [Array<Y2Firewall::Firewalld::Zone>]
      def parse
        return [] if !@zone_names || @zone_names.empty?
        zone = nil
        zones = []
        @zones_definition.reject(&:empty?).each do |line|
          attribute, _value = line.split("\s")
          next if !attribute

          if @zone_names.include?(attribute)
            zone = Zone.new(name: attribute)
            zones << zone
            next
          end

          next unless zone

          attribute, value = line.lstrip.split(":\s")

          next unless zone.respond_to?("#{attribute}=")
          if BOOLEAN_ATTRIBUTES.include?(attribute)
            zone.public_send("#{attribute}=", value == "yes" ? true : false)
          else
            zone.public_send("#{attribute}=", value.to_s.split)
          end
        end

        zones.map { |z| z.modified = [] }

        zones
      end
    end
  end
end
