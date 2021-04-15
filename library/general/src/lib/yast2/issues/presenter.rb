# encoding: utf-8

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

Yast.import "HTML"
Yast.import "RichText"

module Yast2
  module Issues
    # This class converts a list of issues into a message for users
    #
    # @todo Separate by severity, group items, etc.
    class Presenter
      # @return [List] List of issues to present
      attr_reader :issues

      # @param issues [List] Issues list
      def initialize(issues)
        @issues = issues
      end

      # Return the text to be shown to the user regarding the list of issues
      #
      # @return [String] Plain text
      def to_plain
        Yast::RichText.Rich2Plain(to_html)
      end

      # Return the HTML representation of a list of issues
      #
      # @return [String] HTML representing the list of issues
      def to_html
        lines = issues.map do |issue|
          "#{issue.location}: #{issue.message}"
        end
        Yast::HTML.List(lines)
      end
    end
  end
end
