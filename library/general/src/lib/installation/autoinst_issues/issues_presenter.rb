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

Yast.import "HTML"
Yast.import "RichText"

module Installation
  module AutoinstIssues
    # This class converts a list of issues into a message to be shown to users
    #
    # The message will summarize the list of issues, separating them into non-fatal
    # and fatal issues.
    class IssuesPresenter
      include Yast::I18n

      # @return [Installation::AutoinstIssues::List] List of issues
      attr_reader :issues_list

      # Constructor
      #
      # @param issues_list [Installation::AutoinstIssues::List] List of issues
      def initialize(issues_list)
        textdomain "autoinst"
        @issues_list = issues_list
      end

      # Return the text to be shown to the user regarding the list of issues
      #
      # @return [String] Plain text
      def to_plain
        Yast::RichText.Rich2Plain(to_html)
      end

      # Return the text to be shown to the user regarding the list of issues
      #
      # @return [String] HTML formatted text
      def to_html
        fatal, non_fatal = issues_list.partition(&:fatal?)

        parts = []
        parts << error_text(fatal) unless fatal.empty?
        parts << warning_text(non_fatal) unless non_fatal.empty?
        parts << Yast::HTML.Newline

        parts <<
          if fatal.empty?
            _("Do you want to continue?")
          else
            _("Please, correct these problems and try again.")
          end

        parts.join
      end

      # Return warning message with a list of issues
      #
      # @param issues [Array<Installation::AutoinstIssues::Issue>] Array containing issues
      # @return [String] Message
      def warning_text(issues)
        Yast::HTML.Para(
          _("Minor issues were detected:")
        ) + issues_list_content(issues)
      end

      # Return error message with a list of issues
      #
      # @param issues [Array<Installation::AutoinstIssues::Issue>] Array containing issues
      # @return [String] Message
      def error_text(issues)
        Yast::HTML.Para(
          _("Important issues were detected:")
        ) + issues_list_content(issues)
      end

      # Return an HTML representation for a list of issues
      #
      # The issues are grouped by the section of the profile where they were detected.
      # General issues (with no section) are listed first.
      #
      # @return [String] Issues list content
      #
      # @see issues_by_section
      def issues_list_content(issues)
        all_issues = []
        issues_map = issues_by_section(issues)

        if issues_map[:nosection]
          all_issues += issues_map[:nosection].map(&:message)
          issues_map.delete(:nosection)
        end

        issues_map.each do |section, items|
          messages = Yast::HTML.List(items.map(&:message))
          all_issues << "#{location(section)}:#{messages}"
        end

        Yast::HTML.List(all_issues)
      end

      # Return issues grouped by section where they were found
      #
      # @return [Hash<(#parent,#section_name),Installation::AutoinstIssues::Issue>]
      #         Issues grouped by AutoYaST profile section
      def issues_by_section(issues)
        issues.each_with_object({}) do |issue, all|
          section = issue.section || :nosection
          all[section] ||= []
          all[section] << issue
        end
      end

      # Return a human string identifying in which section was detected
      #
      # For instance: "drive[0] > partitions[2] > raid_options"
      #
      # @param section [#parent,#section_name] Section where the problem was detected
      # @return [String]
      #
      # @see Y2Storage::AutoinstProfile
      def location(section)
        return section.section_name if section.parent.nil?

        value = section.parent.send(section.section_name)
        text =
          if value.is_a?(Array)
            index = value.index(section)
            "#{section.section_name}[#{index + 1}]"
          else
            section.section_name
          end

        prefix = location(section.parent)
        prefix << " > " unless prefix.empty?
        prefix + text
      end
    end
  end
end
