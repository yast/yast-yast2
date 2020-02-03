#! /usr/bin/env rspec --format doc

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
require "cwm/progress_bar"

Yast.import "UI"

describe CWM::ProgressBar do
  class TestProgressBar < CWM::ProgressBar
    def steps
      ["step 1", "step 2", "step 3"]
    end
  end

  subject { TestProgressBar.new }

  include_examples "CWM::ProgressBar"

  describe "#forward" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget).with(anything, :Label, anything)

      allow(Yast::UI).to receive(:ChangeWidget).with(anything, :Value, anything)
    end

    context "when the progress bar is complete" do
      before do
        3.times { subject.forward }
      end

      it "does not modify the progress bar" do
        expect(Yast::UI).to_not receive(:ChangeWidget).with(anything, :Value, anything)
        expect(Yast::UI).to_not receive(:ChangeWidget).with(anything, :Label, anything)

        subject.forward
      end
    end

    context "when the progress bar is not complete" do
      before do
        subject.forward # there are three steps
      end

      it "moves progress forward" do
        expect(Yast::UI).to_not receive(:ChangeWidget).with(anything, :Value, 1)

        subject.forward
      end

      context "and steps should be shown" do
        before do
          allow(subject).to receive(:show_steps?).and_return(true)
        end

        it "updates the label according to the step" do
          expect(Yast::UI).to_not receive(:ChangeWidget).with(anything, :Label, "step 2")

          subject.forward
        end
      end

      context "and steps should not be shown" do
        before do
          allow(subject).to receive(:show_steps?).and_return(false)
        end

        it "shows an empty label" do
          expect(Yast::UI).to receive(:ChangeWidget).with(anything, :Label, "")

          subject.forward
        end
      end
    end
  end
end
