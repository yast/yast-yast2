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
require "y2firewall/firewalld/relations"

module Y2Firewall
  class Firewalld
    # Class to work with Firewalld services
    #
    #
    # # @example
    #
    #   ha = firewalld.find_service("high-availability")
    #   ha.ports # => ["2224/tcp", "3121/tcp", "5403/tcp", "5404/udp",
    #   "5405/udp", "21064/tcp"]
    #
    #   ha.tcp_ports #=> ["2224", "3121", "5403", "21064"]
    #   ha.udp_ports #=> ["5404", "5405"]
    #
    class Service
      # Service was not found
      class NotFound < StandardError
        def initialize(name)
          super "Service '#{name}' not found"
        end
      end

      extend Relations
      include Yast::I18n
      extend Yast::I18n

      # @return [String] service name
      attr_reader :name

      has_many :ports, :protocols, scope: "service", cache: true
      has_attributes :short, :description, scope: "service", cache: true

      # Convenience method for setting the tcp and udp ports of a given
      # service. If the service is found, it modify the ports according to the
      # given parameters applying the changes at the end.
      #
      # @example
      #   Y2Firewall::Firewalld::Service.modify_ports("apach", tcp_ports:
      #   ["80", "8080"]) #=> Y2Firewall::Firewalld::Service::NotFound
      #
      #   Y2Firewall::Firewalld::Service.modify_ports("apache2", tcp_ports:
      #   ["80", "8080"]) #=> true
      #
      # @param name [String] service name
      # @param tcp_ports [Array<String>] tcp ports to be opened by the service
      # @param udp_ports [Array<String>] udp ports to be opened by the service
      # @return [Boolean] true if modified; false otherwise
      def self.modify_ports(name:, tcp_ports: [], udp_ports: [])
        return false unless Firewalld.instance.installed?

        service = Firewalld.instance.find_service(name)
        service.ports = tcp_ports.map { |p| "#{p}/tcp" } + udp_ports.map { |p| "#{p}/udp" }
        service.apply_changes!
      end

      # Constructor
      #
      # @param name [String] zone name
      def initialize(name:)
        @name = name
        @ports = []
        @protocols = []
      end

      # Create the service in firewalld
      def create!
        api.create_service(name)
      end

      # Return whether the service is available in firewalld or not
      #
      # @return [Boolean] true if defined; false otherwise
      def supported?
        api.service_supported?(name)
      end

      # Read the firewalld configuration initializing the object accordingly
      #
      # @return [Boolean] true if read
      def read
        return false unless supported?

        read_attributes
        read_relations
        untouched!
        true
      end

      # Apply the changes done since read in firewalld
      #
      # @return [Boolean] true if applied; false otherwise
      def apply_changes!
        return true if !modified?
        return false if !supported?

        apply_attributes_changes!
        apply_relations_changes!
        untouched!
        true
      end

      # Convenience method to select only the service tcp ports
      #
      # @return [Array<String>] array with the service tcp ports
      def tcp_ports
        ports.select { |p| p.include?("tcp") }.map { |p| p.sub("/tcp", "") }
      end

      # Convenience method to select only the service udp ports
      #
      # @return [Array<String>] array with the service udp ports
      def udp_ports
        ports.select { |p| p.include?("udp") }.map { |p| p.sub("/udp", "") }
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
