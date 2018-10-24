#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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

require "cwm/popup"
require "cwm/rspec"

describe CWM::Popup do
  class TestCWMPopup < CWM::Popup
    def contents
      VBox()
    end
  end

  subject { TestCWMPopup.new }

  include_examples "CWM::Dialog"

  describe ".run" do
    before do
      allow(Yast::Wizard).to receive(:IsWizardDialog).and_return(wizard_dialog?)
      allow(Yast::CWM).to receive(:show).and_return(:launch)
    end

    context "when running on a wizard" do
      let(:wizard_dialog?) { true }

      it "always opens a dialog" do
        expect(Yast::UI).to receive(:OpenDialog).with(Yast::Term)
        TestCWMPopup.run
      end
    end

    context "when not running on a wizard" do
      let(:wizard_dialog?) { false }

      it "always opens a dialog" do
        expect(Yast::UI).to receive(:OpenDialog).with(Yast::Term)
        TestCWMPopup.run
      end
    end
  end
end
