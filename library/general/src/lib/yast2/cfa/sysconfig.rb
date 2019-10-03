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
require "cfa/vendor_loader"
require "yast2/cfa/agent_handler"

class IdentityParser
  attr_reader :empty

  def initialize(empty)
    @empty = empty
  end

  def serialize(data)
    data
  end

  def parse(data)
    data
  end
end

module Yast2
  module CFA
    # This class offers an CFA API to the {SysConfigFile} source of {ag_ini} agents.
    #
    # @example Modifying a sysconfig file
    #   keyboard = Sysconfig.new("keyboard")
    #   keyboard.load
    class Sysconfig < ::CFA::BaseModel
      SYSCONFIG_DIRECTORY = "/etc/sysconfig".freeze

      def initialize(path, options = {})
        @path = path
        abs_path = File.join(SYSCONFIG_DIRECTORY, path)
        parser = IdentityParser.new({})
        file_handler = Yast2::CFA::AgentHandler.new(:ag_ini, :SysConfigFile, options)
        load_handler = ::CFA::VendorLoader.new(
          parser: parser,
          file_handler: file_handler,
          file_path: abs_path
        )
        super(
          parser, abs_path, file_handler: file_handler, load_handler: load_handler
        )
      end

      def []=(key, value)
        @data[key] = value
      end
    end
  end
end
