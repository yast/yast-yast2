# Copyright (c) [2020] SUSE LLC
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

require "forwardable"

module Y2Issues
  # List of YaST issues
  class List
    include Enumerable
    extend Forwardable

    def_delegators :@items, :each, :empty?, :<<

    # Constructor
    #
    # @param issues [Array<Issue>] Issues to include in the list
    def initialize(issues = [])
      @items = issues
    end

    # Determine whether any of the problem on the list is an error
    #
    # @return [Boolean] true if any of them is an error
    def error?
      any?(&:error?)
    end

    # Returns an array containing registered problems
    #
    # @return [Array<Issue>] List of problems
    def to_a
      @items
    end
  end
end
