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
require "cfa/login_defs"

Yast.import "FileUtils"

module CFA
  # This class allows to interact with the login.defs configuration files
  #
  # @example Reading a configuration parameter value
  #   config = LoginDefsConfig.new
  #   config.load
  #   config.encrypt_method #=> "SHA512"
  #
  # @example Setting a value
  #   config = LoginDefsConfig.new
  #   config.load
  #   config.fail_delay = "5"
  #   config.save
  class LoginDefsConfig
    YAST_FILE_PATH = "/etc/login.defs.d/70-yast.conf".freeze

    class << self
      # Define an attribute
      #
      # @param attr [Symbol] Attribute name
      def define_attr(attr)
        define_method attr do
          file = files.reverse.find { |f| f.present?(attr) }
          return file.public_send(attr) if file

          yast_config_file.public_send(attr)
        end

        define_method "#{attr}=" do |value|
          yast_config_file.public_send("#{attr}=", value)
        end
      end
    end

    LoginDefs.known_attributes.each { |a| define_attr(a) }

    # Returns the path to the local configuration file
    #
    # @return [String] File path
    def local_file_path
      "/etc/login.defs"
    end

    # Returns the path to the vendor configuration file
    #
    # @return [String] File path
    def vendor_file_path
      "/usr/etc/login.defs"
    end

    # Loads the configuration
    def load
      files.each(&:load)
    end

    # Save changes to the YaST specific file
    def save
      yast_config_file.save
    end

    # Returns the conflicting attributes
    #
    # @return [Array<Symbol>]
    def conflicts
      higher_precedence_files.each_with_object([]) do |file, attrs|
        attrs.concat(yast_config_file.conflicts(file))
      end
    end

  private

    # Return the involved configuration files
    #
    # @return [Array<LoginDefs>] Configuration files
    # @see #paths
    def files
      @files ||= paths.map { |p| LoginDefs.new(file_path: p) }
    end

    # Return the paths to the configuration files
    #
    # @return [Array<String>]
    def paths
      @paths ||=
        if Yast::FileUtils.Exists(local_file_path)
          [local_file_path] + local_override_paths
        else
          paths = Yast::FileUtils.Exists(vendor_file_path) ? [vendor_file_path] : []
          paths + vendor_override_paths + local_override_paths
        end
    end

    # Returns the paths of the local override files (including the YaST one)
    #
    # @return [Array<String>]
    def local_override_paths
      (override_paths(local_file_path) + [YAST_FILE_PATH]).uniq.sort
    end

    # Returns the paths of the vendor override files
    #
    # @return [Array<String>]
    def vendor_override_paths
      override_paths(vendor_file_path)
    end

    # @param path [String]
    # @return [Array<String>]
    def override_paths(path)
      directory = "#{path}.d"
      paths = Yast::SCR.Read(Yast::Path.new(".target.dir"), directory)
      return [] if paths.nil?

      paths.map { |p| File.join(directory, p) }
    end

    # Returns the YaST specific configuration file
    #
    # @return [LoginDefs]
    def yast_config_file
      @yast_config_file ||= files.find { |f| f.file_path == YAST_FILE_PATH }
    end

    # Returns the files with higher precedence that the YaST one
    #
    # @return [Array<LoginDefs>] List of files
    def higher_precedence_files
      return @higher_precedence_files if @higher_precedence_files

      yast_config_file_idx = files.find_index { |f| f == yast_config_file }
      @higher_precedence_files ||= files[yast_config_file_idx + 1..]
    end
  end
end
