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
require "yast2/target_file"

module CFA
  # CFA based API to adjust the sysctl tool configuration
  #
  # This class does not modify the running kernel configuration. It just writes
  # the desired values into the configuration file ({PATH}).
  #
  # @example Setting a value using they +sysctl.conf+ key
  #   sysctl = Sysctl.new
  #   sysctl.load
  #   sysctl["net.ipv4.ip_forward"] = "1"
  #   sysctl.save
  #
  # @example Setting a value using an accessor
  #   sysctl = Sysctl.new
  #   sysctl.forward_ipv4 = "1"
  #   sysctl.save
  class Sysctl < ::CFA::BaseModel
    PARSER = ::CFA::AugeasParser.new("sysctl.lns")
    PATH = "/etc/sysctl.d/50-yast.conf".freeze

    class << self
      # Adds a helper method to get a boolean value from boolean-like attributes ("1" or "0")
      #
      # @param attr [Symbol] Attribute name
      def boolean_attr(*attrs)
        attrs.each do |attr|
          define_method "#{attr}?" do
            public_send(attr) == "1"
          end
        end
      end
    end

    ATTRIBUTES = {
      kernel_sysrq:   "kernel.sysrq",
      forward_ipv4:   "net.ipv4.ip_forward",
      forward_ipv6:   "net.ipv6.conf.all.forwarding",
      tcp_syncookies: "net.ipv4.tcp_syncookies",
      disable_ipv6:   "net.ipv6.conf.all.disable_ipv6"
    }.freeze

    attributes(ATTRIBUTES)

    boolean_attr :forward_ipv4, :forward_ipv6, :tcp_syncookies, :disable_ipv6

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

      known_keys.each do |key|
        next if data[key]

        old_value = Yast::SCR.Read(SYSCTL_AGENT_PATH + key)
        data[key] = old_value if old_value
      end
      nil
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

    # Path to the agent to handle the +/etc/sysctl.conf+ file
    SYSCTL_AGENT_PATH = Yast::Path.new(".etc.sysctl_conf")

    # Remove values from `/etc/sysctl.conf` to reduce noise and confusion
    def clean_old_values
      known_keys.each do |key|
        Yast::SCR.Write(SYSCTL_AGENT_PATH + key, nil)
      end
      Yast::SCR.Write(SYSCTL_AGENT_PATH, nil)
    end

    # Returns the list of known attributes
    #
    # Just a helper method to get the list of defined attributes
    #
    # @return [String<Symbol>]
    def known_keys
      @known_keys ||= ATTRIBUTES.values
    end
  end
end
