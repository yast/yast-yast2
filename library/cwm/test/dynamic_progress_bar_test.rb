#! /usr/bin/env rspec --format doc
# typed: false

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

require_relative "test_helper"

require "cwm/rspec"
require "cwm/dynamic_progress_bar"

Yast.import "UI"

describe CWM::DynamicProgressBar do
  class TestDynamicProgressBar < CWM::DynamicProgressBar
    def steps_count
      3
    end

    def label
      "Progress"
    end
  end

  subject { TestDynamicProgressBar.new }

  include_examples "CWM::DynamicProgressBar"

  describe "#forward" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget).with(anything, :Label, anything)

      allow(Yast::UI).to receive(:ChangeWidget).with(anything, :Value, anything)
    end

    context "when the step is given" do
      let(:step) { "step 1" }

      it "updates the label according to the given step" do
        expect(Yast::UI).to receive(:ChangeWidget).with(anything, :Label, step)

        subject.forward(step)
      end
    end

    context "when the step is not given" do
      it "updates the label according to the defined label" do
        expect(Yast::UI).to receive(:ChangeWidget).with(anything, :Label, "Progress")

        subject.forward
      end
    end
  end
end
