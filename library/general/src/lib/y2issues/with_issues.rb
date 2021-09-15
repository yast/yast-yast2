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

require "y2issues"

module Y2Issues
  # Mixin that provides a helper method to work with a list of issues
  #
  # @example
  #   class Example
  #     include Y2Issues::WithIssues
  #
  #     def do_something
  #       with_issues do |issues|
  #         issues < Y2Issues::Issue.new("can do nothing")
  #       end
  #     end
  #   end
  #
  #   example = Example.new
  #   example.do_something  #=> Y2Issues::List
  module WithIssues
    # Executes the given block passing a list of issues
    #
    # @return [Y2Issues::List] list of issues filled in the block execution
    def with_issues(&block)
      issues = Y2Issues::List.new
      block.call(issues)
      issues
    end
  end
end
