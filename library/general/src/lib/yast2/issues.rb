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

module Yast2
  # This module offers a mechanism to register and report issues to the user.
  #
  # It includes:
  #
  # * A set of classes to represent the issues ({Yast2::Issues::Issue},
  #   {Yast2::Issues::InvalidValue}).
  # * A class to collect errors ({Yast2::Issues::List}).
  # * A presenter to help when presenting the issues to the user ({Yast2::Issues::Presenter}).
  #
  # @example Registering an error
  #   list = Yast2::Issues::List.new
  #   list << Yast2::Issues::Issue.new("Could not read network configuration", severity: :fatal)
  module Issues
  end
end

require "yast2/issues/list"
require "yast2/issues/presenter"
require "yast2/issues/location"

# Issues types
require "yast2/issues/issue"
require "yast2/issues/invalid_value"
