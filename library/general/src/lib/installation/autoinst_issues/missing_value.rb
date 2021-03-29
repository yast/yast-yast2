# typed: true
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

require "installation/autoinst_issues/issue"

module Installation
  module AutoinstIssues
    # Represents an AutoYaST situation where a mandatory value is missing.
    #
    # @example Missing value for attribute 'bar' in 'foo' section.
    #   problem = AyMissingValue.new("foo","bar")
    class MissingValue < ::Installation::AutoinstIssues::Issue
      attr_reader :section, :attribute
      attr_reader :description, :severity

      # @param section     [String] Section where it was detected
      # @param attribute   [String] Name of the missing attribute
      # @param description [String] additional explanation; optional
      # @param severity    [Symbol] :warn, :fatal = abort the installation ; optional
      def initialize(section, attr, description = "", severity = :warn)
        textdomain "base"

        @section = section
        @attribute = attr
        @description = description
        @severity = severity
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS:
        # 'attr' is an AutoYaST element
        # 'description' has already been translated in other modules.
        format(_("Missing element '%{attr}'. %{description}"), attr: attribute, description: description)
      end
    end
  end
end
