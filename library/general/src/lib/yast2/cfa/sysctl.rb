# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "cfa/base_model"

module Yast2
  module CFA
    # CFA based API to adjust the sysctl tool configuration
    #
    # This class does not modify the running kernel configuration. It just writes
    # the desired values into the configuration file ({PATH}).
    #
    # @example Setting IPv4 forwarding setting
    #   sysctl = Sysctl.new
    #   sysctl.forward_ipv4 = "1"
    #   sysctl.save
    class Sysctl < ::CFA::BaseModel
      PARSER = ::CFA::AugeasParser.new("sysctl.lns")
      PATH = "/etc/50-yast.conf".freeze

      # sysctl keys, used as *single* SCR path components below
      IPV4_SYSCTL = "net.ipv4.ip_forward".freeze
      IPV6_SYSCTL = "net.ipv6.conf.all.forwarding".freeze

      private_constant :IPV4_SYSCTL
      private_constant :IPV6_SYSCTL

      class << self
        # Defines an accessor for a given value
        #
        # @param meth [Symbol] Accessor name
        # @param key  [String] Value key (e.g., "net.ipv4.ip_forward")
        def define_accessor(meth, key)
          define_method meth do
            data[key]
          end

          define_method "#{meth}=" do |value|
            data[key] = value
          end
        end
      end

      define_accessor :forward_ipv4, IPV4_SYSCTL
      define_accessor :forward_ipv6, IPV6_SYSCTL

      def initialize(file_handler: nil)
        super(PARSER, PATH, file_handler: file_handler)
      end

      # Loads sysctl content
      #
      # This method reads {PATH} and uses `/etc/sysctl.conf` values as fallback.
      def load
        begin
          super
        rescue Errno::ENOENT # PATH does not exist yet
          self.data = @parser.empty
          @loaded = true
        end
        self.forward_ipv4 = Yast::SCR.Read(Yast::Path.new(SYSCTL_IPV4_PATH)) if forward_ipv4.nil?
        self.forward_ipv6 = Yast::SCR.Read(Yast::Path.new(SYSCTL_IPV6_PATH)) if forward_ipv6.nil?
      end

      # Writes sysctl configuration
      #
      # Apart from writing the values to {PATH}, it cleans up the same entries from
      # `/etc/sysctl.conf`.
      def save
        super
        clean_old_values
      end

    private

      # SCR paths IPv4 / IPv6 Forwarding
      SYSCTL_AGENT_PATH = ".etc.sysctl_conf".freeze
      SYSCTL_IPV4_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV4_SYSCTL}\"").freeze
      SYSCTL_IPV6_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV6_SYSCTL}\"").freeze

      # Remove values from `/etc/sysctl.conf` to reduce noise and confusion
      def clean_old_values
        Yast::SCR.Write(Yast::Path.new(SYSCTL_IPV4_PATH), nil)
        Yast::SCR.Write(Yast::Path.new(SYSCTL_IPV6_PATH), nil)
        Yast::SCR.Write(Yast::Path.new(SYSCTL_AGENT_PATH), nil)
      end
    end
  end
end
