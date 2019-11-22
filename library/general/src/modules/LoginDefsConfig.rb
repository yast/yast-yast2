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

require "yast"
require "cfa/login_defs_config"

module Yast
  # This class allows to access the API to handle login.defs attributes from Perl
  #
  # @see CFA::LoginDefs
  # @see CFA::LoginDefsConfig
  class LoginDefsConfigClass < Module
    include Logger

    # The given attribute is unknown
    class UnknownAttributeError < StandardError; end

    # Module initialization
    def main
      textdomain "base"
    end

    # Resets the configuration
    #
    # It forces to read the configuration again discarding
    # the changes.
    def reset
      @config = nil
    end

    # Returns an attribute from login.defs configuration
    #
    # @example Getting the encryption method
    #   Yast::LoginDefsConfig.fetch(:encrypt_method) #=> "SHA512"
    #
    # @example Getting the encryption method using the variable name
    #   Yast::LoginDefsConfig.fetch(ENCRYPT_METHOD) #=> "SHA512"
    #
    # @param attr [String,Symbol] Attribute name
    # @return [String,nil] Attribute value
    def fetch(attr)
      normalized_attr = attr.to_s.downcase
      check_attribute(normalized_attr)
      config.public_send(normalized_attr)
    end

    # Sets an attribute to login.defs
    #
    # @example Setting the encryption method
    #   Yast::LoginDefsConfig.set(:encrypt_method, "SHA512")
    #
    # @param attr [String,Symbol] Attribute name
    # @param value [String,nil] Attribute value
    def set(attr, value)
      normalized_attr = attr.to_s.downcase
      check_attribute(normalized_attr)
      config.public_send("#{normalized_attr}=", value)
    end

    # Writes the login.defs configuration
    def write
      config.save
    end

    publish function: :fetch, type: "any (string)"
    publish function: :set, type: "void (string, string)"
    publish function: :write, type: "void ()"
    publish function: :reset, type: "void ()"

  private

    # Check whether the attribute is known
    #
    # @raise UnknownAttributeError
    def check_attribute(attr)
      return if config.respond_to?(attr)

      raise UnknownAttributeError, "Unknown attribute #{attr} for login.defs"
    end

    # Returns the current login.defs configuration
    #
    # @return CFA::LoginDefsConfig
    # @see CFA::LoginDefsConfig
    def config
      return @config if @config

      @config = CFA::LoginDefsConfig.new
      @config.load
      @config
    end
  end

  LoginDefsConfig = LoginDefsConfigClass.new
  LoginDefsConfig.main
end
