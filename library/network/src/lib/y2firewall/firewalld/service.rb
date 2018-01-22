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

      attr_accessor :name
      attr_accessor :short
      attr_accessor :description

      has_many :ports, :protocols, scope: "service"

      # Constructor
      #
      # @param name [String] zone name
      def initialize(name: nil)
        @name = name
      end

      def create!
        api.add_service(name)
      end

      def supported?
        api.service_supported?(name)
      end

      def read
        return false unless supported?

        @short        = api.service_short(name)
        @description  = api.service_description(name)
        @protocols    = current_protocols
        @ports        = current_ports

        true
      end

      def apply_changes!
        create! unless supported?

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
