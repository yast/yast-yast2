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

require "ui/wizards/layout"

describe UI::Wizards::Layout do
  describe ".with_steps" do
    it "creates a layout with steps sidebar" do
      layout = described_class.with_steps

      expect(layout.mode.steps?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_steps

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".with_title_on_left" do
    it "creates a layout with dialog title on left" do
      layout = described_class.with_title_on_left

      expect(layout.mode.title_on_left?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_title_on_left

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".with_title_on_top" do
    it "creates a layout with dialog title on top" do
      layout = described_class.with_title_on_top

      expect(layout.mode.title_on_top?).to eq(true)
    end

    it "creates a layout with banner disabled" do
      layout = described_class.with_title_on_top

      expect(layout.banner?).to eq(false)
    end
  end

  describe ".from_product_features" do
    before do
      Yast.import "ProductFeatures"

      Yast::ProductFeatures.Import(product_features)
    end

    let(:product_features) do
      {
        "globals" => {
          "installation_ui"     => installation_ui,
          "installation_layout" => installation_layout
        }
      }
    end

    shared_examples "installation_ui option" do
      context "and installation_ui option is not set either" do
        let(:installation_ui) { nil }

        it "sets title-on-left mode" do
          layout = described_class.from_product_features

          expect(layout.mode.title_on_left?).to eq(true)
        end

        it "enables the banner" do
          layout = described_class.from_product_features

          expect(layout.banner?).to eq(true)
        end
      end

      context "and installation_ui option is set to an unknown value" do
        let(:installation_ui) { "foo" }

        it "sets title-on-left mode" do
          layout = described_class.from_product_features

          expect(layout.mode.title_on_left?).to eq(true)
        end

        it "enables the banner" do
          layout = described_class.from_product_features

          expect(layout.banner?).to eq(true)
        end
      end

      context "and installation_ui option is set to sidebar value" do
        let(:installation_ui) { "sidebar" }

        it "sets steps mode" do
          layout = described_class.from_product_features

          expect(layout.mode.steps?).to eq(true)
        end

        it "disables the banner" do
          layout = described_class.from_product_features

          expect(layout.banner?).to eq(false)
        end
      end
    end

    context "when installation_layout option is not set in the product features" do
      let(:installation_layout) { nil }

      include_examples "installation_ui option"
    end

    context "when installation_layout option is set in the product features" do
      let(:installation_layout) do
        {
          "mode"   => "steps",
          "banner" => true
        }
      end

      let(:installation_ui) { nil }

      it "sets the mode according to the mode option" do
        layout = described_class.from_product_features

        expect(layout.mode.steps?).to eq(true)
      end

      it "sets the banner according to the banner option" do
        layout = described_class.from_product_features

        expect(layout.banner?).to eq(true)
      end

      context "and the mode option is not set in the product features" do
        let(:installation_layout) do
          {
            "banner" => true
          }
        end

        it "keeps the default mode" do
          layout = described_class.from_product_features

          expect(layout.mode.title_on_top?).to eq(true)
        end
      end

      context "and the banner option is not set in the product features" do
        let(:installation_layout) do
          {
            "mode" => "steps"
          }
        end

        it "keeps the default banner value" do
          layout = described_class.from_product_features

          expect(layout.banner?).to eq(false)
        end
      end

      context "and neither the mode nor the banner options are set" do
        let(:installation_layout) { "" }

        include_examples "installation_ui option"
      end
    end
  end

  describe "#open_wizard" do
    before do
      allow(Yast::Wizard).to receive(:OpenWithLayout)
    end

    subject { described_class.with_steps }

    it "opens the wizard with the configured layout" do
      expect(Yast::Wizard).to receive(:OpenWithLayout).with(subject)

      subject.open_wizard
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
