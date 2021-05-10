# Copyright (c) [2021] SUSE LLC
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

require "singleton"
require "yaml"

require "yast"

module Installation
  #
  # Class which collects all installation/update information in order
  # to write it into the /var/log/YaST2/installation_info directory
  # when the process has been finished correctly or the process has
  # crashed.
  class InstallationInfo
    include Singleton
    include Yast::Logger

    LOGDIR = "/var/log/YaST2/installation_info/".freeze

    include Yast::Logger

    def initialize
      self.index = 0

      # Function calls which has been set by other modules,
      # these functions will be called while generating the output.
      # The return value (hash) of each call will be logged into the output file.
      # Uses "id" => block mapping
      @callbacks = {}
    end
    
    # Register a block which will be called while generating the data file.
    #
    # Example:
    #
    #     require "installation/installation_info"
    #
    #     ::Installation::InstallationInfo.instance.add("my_module") do
    #       MyClass.collect_data
    #     end
    #
    # @param name [String] id of the function call, using the same id
    #   will overwrite the previous setting, use the module/package name
    #   to avoid conflicts
    def add(name, &block)
      return unless block_given?

      log.info("Adding callback #{name.inspect}")
      callbacks[name] = block
    end

    # is the callback already registered?
    # @param name [String] name of the callback
    # @return [Boolean] `true` if registered, `false` otherwise
    def included?(name)
      callbacks.key?(name)
    end

    # Collects the data and writes the dump into an YAML file.
    #
    # @param description [String] description of data, e.g. what happened
    # @param additional_info [Hash,nil] optional additional information
    # @param path [String,nil] path to the saved dump file,
    #   uses the default path if `nil`
    # @return [String] path to the written file
    def write(description, additional_info = nil, path = nil)
      file = path || File.join(LOGDIR, "dump_#{Process.pid}_#{format("%03d", index)}.yml")
      log.info("Writing installation information to #{file}")

      # the collected data
      data = {}

      @callbacks.each do |name, callback|
        data[name] = callback.call
      end

      data["description"] = description
      data["additional_info"] = additional_info if additional_info

      ::FileUtils.mkdir_p(File.dirname(file))
      File.write(file, data.to_yaml)

      # increase the file counter for the next file
      self.index += 1

      file
    end

  protected

    attr_reader :callbacks
    attr_accessor :index
  end
end
