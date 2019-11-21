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
require "cfa/base_model"
require "yast2/target_file"

module CFA
  # Model to handle login.defs configuration files
  #
  # @example Reading a value
  #   file = LoginDefs.new(file_path: "/etc/login.defs")
  #   file.load
  #   file.encrypt_method #=> "SHA512"
  #
  # @example Writing a value
  #   file = LoginDefs.new(file_path: "/etc/login.defs.d/70-yast.conf")
  #   file.encrypt_method = "DES"
  #   file.save
  #
  # @example Loading shortcut
  #   file = LoginDefs.load(file_path: "/etc/login.defs.d/70-yast.conf")
  #   file.encrypt_method #=> "SHA512"
  class LoginDefs < BaseModel
    include Yast::Logger

    # @return [Array<Symbol>] List of known login.defs attributes
    KNOWN_ATTRIBUTES = [
      :character_class,
      :encrypt_method,
      :fail_delay,
      :gid_max,
      :gid_min,
      :groupadd_cmd,
      :pass_max_days,
      :pass_min_days,
      :pass_warn_age,
      :sys_gid_max,
      :sys_gid_min,
      :sys_uid_max,
      :sys_uid_min,
      :uid_max,
      :uid_min,
      :useradd_cmd,
      :userdel_postcmd,
      :userdel_precmd
    ].freeze

    class << self
      # Returns the list of known attributes
      #
      # @return [Array<Symbol>]
      def known_attributes
        KNOWN_ATTRIBUTES
      end

      # Instantiates and loads a file
      #
      # This method is basically a shortcut to instantiate and load the content in just one call.
      #
      # @param file_handler [#read,#write] something able to read/write a string (like File)
      # @param file_path    [String] File path
      # @return [LoginDefs] File with the already loaded content
      def load(file_path:, file_handler: Yast::TargetFile)
        new(file_path: file_path, file_handler: file_handler).tap(&:load)
      end
    end

    attributes(
      known_attributes.each_with_object({}) { |a, hsh| hsh[a] = a.to_s.upcase }
    )

    # @return [String] File path
    attr_reader :file_path

    # Constructor
    #
    # @param file_handler [#read,#write] something able to read/write a string (like File)
    # @param file_path    [String] File path
    #
    # @see CFA::BaseModel#initialize
    def initialize(file_path:, file_handler: Yast::TargetFile)
      super(AugeasParser.new("login_defs.lns"), file_path, file_handler: file_handler)
    end

    # Determines whether an attribute has a value
    #
    # @return [Boolean] +true+ if it is defined; +false+ otherwise.
    def present?(attr)
      !public_send(attr).nil?
    end

    # Returns the list of attributes with a value
    #
    # @return [Array<Symbol>] List of attribute names
    # @see #present?
    def present_attributes
      self.class.known_attributes.select { |a| present?(a) }
    end

    # Determines the list of conflicting attributes for two files
    #
    # Two attributes are conflicting when both of them are defined with
    # different values.
    #
    # @param other [BaseModel] The file to compare with
    # @return [Array<Symbol>] List of conflicting attributes
    def conflicts(other)
      conflicting_attrs = present_attributes & other.present_attributes
      conflicting_attrs.reject { |a| public_send(a) == other.public_send(a) }
    end

    # Loads the file content
    #
    # If the file does not exist, consider the file as empty.
    def load
      super
    rescue Errno::ENOENT # PATH does not exist yet
      self.data = @parser.empty
      @loaded = true
    end
  end
end
