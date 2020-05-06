#!/usr/bin/env rspec
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

require_relative "../test_helper"
require "installation/autoinst_profile/section_with_attributes"
require "installation/autoinst_issues/issue"
require "installation/autoinst_issues/list"
require "installation/autoinst_issues/issues_presenter"

module Installation
  module AutoinstIssues
    
    class MissingSection < ::Installation::AutoinstIssues::Issue
      def initialize(*args)
        super
      end

      def severity
        :fatal
      end

      def message
        "No section was found."
      end
    end

    class InvalidValue < ::Installation::AutoinstIssues::Issue
      attr_reader :attr
      attr_reader :value

      def initialize(section, attr, value)
        @section = section
        @attr = attr
        @value = value
      end

      def severity
        :warn
      end

      def message
        format(
          "Invalid value '%{value}' for attribute '%{attr}'.",
          value:             value,
          attr:              attr
        )
      end
    end
    
  end
end

describe Installation::AutoinstIssues::IssuesPresenter do
  subject(:presenter) { described_class.new(list) }
  let(:section) do
    ::Installation::AutoinstProfile::SectionWithAttributes.new_from_hashes({})
  end

  let(:list) { ::Installation::AutoinstIssues::List.new }

  describe "#to_html" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_section)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Important issues"
      end
    end

    context "when a non fatal issue was found" do
      before do
        list.add(:invalid_value, section, "foo", "bar")
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Minor issues"
      end

      it "includes the location information" do
        expect(presenter.to_html).to include "<li>Invalid value"
      end
    end

    context "when a non located issue was found" do
      before do
        list.add(:missing_section)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end
    end
  end

  describe "#to_plain" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_section)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Important issues"
      end
    end

    context "when a non fatal issue was found" do
      before do
        list.add(:invalid_value, section, "foo", "bar")
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Minor issues"
      end

      it "includes the location information" do
        expect(presenter.to_plain).to include "* Invalid value"
      end
    end

    context "when a non located issue was found" do
      before do
        list.add(:missing_section)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end
    end
  end
end
