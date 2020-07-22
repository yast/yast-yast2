#! /usr/bin/env rspec

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

require_relative "../../test_helper"

require "ui/installation/layout"

describe UI::Installation::Layout do
  describe ".with_steps" do
    it "creates a layout with steps sidebar" do
      layout = described_class.with_steps

      expect(layout.with_steps?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_steps

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".with_title_on_left" do
    it "creates a layout with dialog title on left" do
      layout = described_class.with_title_on_left

      expect(layout.with_title_on_left?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_title_on_left

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".with_title_on_top" do
    it "creates a layout with dialog title on top" do
      layout = described_class.with_title_on_top

      expect(layout.with_title_on_top?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_title_on_top

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".from_product_features" do
    before do
      allow(UI::Installation::LayoutConfig).to receive(:from_product_features).and_return(config)
    end

    let(:config) do
      instance_double(UI::Installation::LayoutConfig,
        mode: UI::Installation::LayoutConfig::Mode::STEPS, banner: true)
    end

    it "creates a layout according to the product features" do
      layout = described_class.from_product_features

      expect(layout.with_steps?).to eq(true)
      expect(layout.banner?).to eq(true)
    end
  end

  describe "#open_wizard" do
    before do
      allow(Yast::Wizard).to receive(:OpenNextBackStepsDialog)
    end

    subject { described_class.with_steps }

    context "when the banner is enabled" do
      before do
        subject.show_banner
      end

      it "shows the banner" do
        expect(Yast::UI).to receive(:SetProductLogo).with(true)

        subject.open_wizard
      end
    end

    context "when the banner is disabled" do
      before do
        subject.hide_banner
      end

      it "hides the banner" do
        expect(Yast::UI).to receive(:SetProductLogo).with(false)

        subject.open_wizard
      end
    end

    context "when the layout was created with steps" do
      subject { described_class.with_steps }

      it "opens a wizard with steps" do
        expect(Yast::Wizard).to receive(:OpenNextBackStepsDialog)

        subject.open_wizard
      end
    end

    context "when the layout was created with title on left" do
      subject { described_class.with_title_on_left }

      it "opens a wizard with title on left" do
        expect(Yast::Wizard).to receive(:OpenLeftTitleNextBackDialog)

        subject.open_wizard
      end
    end

    context "when the layout was created with title on top" do
      subject { described_class.with_title_on_top }

      it "opens a wizard with title on top" do
        expect(Yast::Wizard).to receive(:OpenNextBackDialog)

        subject.open_wizard
      end
    end

    context "when a block is given" do
      before do
        allow(Yast::Wizard).to receive(:CloseDialog)
      end

      it "calls the block" do
        expect { |b| subject.open_wizard(&b) }.to yield_control
      end

      it "closes the wizard" do
        expect(Yast::Wizard).to receive(:CloseDialog)

        subject.open_wizard {}
      end
    end

  end
end
