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

      # @return name [String] service name
      attr_reader :name
      # @return short [String] service short description
      attr_reader :short
      # @return description [String] service long description
      attr_reader :description

      has_many :ports, :protocols, scope: "service"

      # Constructor
      #
      # @param name [String] zone name
      def initialize(name:)
        @name = name
      end

      # Create the service in firewalld
      def create!
        api.add_service(name)
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

        @short        = api.service_short(name)
        @description  = api.service_description(name)
        @protocols    = current_protocols
        @ports        = current_ports

        true
      end

      # Apply the changes done since read in firewalld
      #
      # @return [Boolean] true if applied; false otherwise
      def apply_changes!
        return false unless supported?

        apply_protocols_changes!
        apply_ports_changes!

        true
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
