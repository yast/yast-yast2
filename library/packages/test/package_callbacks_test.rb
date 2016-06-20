#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackageCallbacks"
Yast.import "Mode"
Yast.import "UI"

describe Yast::PackageCallbacks do
  subject { Yast::PackageCallbacks }

  describe "#textmode" do
    subject(:textmode) { Yast::PackageCallbacks.send(:textmode) }

    before do
      allow(Yast::Mode).to receive(:commandline).and_return commandline
      allow(Yast::UI).to receive(:GetDisplayInfo)
        .and_return("TextMode" => display_textmode)
    end

    context "running in CLI" do
      let(:commandline) { true }
      let(:display_textmode) { nil }

      it "returns true" do
        expect(textmode).to eq true
      end
    end

    context "running in TUI" do
      let(:commandline) { false }
      let(:display_textmode) { true }

      it "returns true" do
        expect(textmode).to eq true
      end
    end

    context "in other cases" do
      let(:commandline) { false }
      let(:display_textmode) { false }

      it "returns false" do
        expect(textmode).to eq false
      end
    end
  end

  describe "#display_width" do
    before do
      allow(Yast::Mode).to receive(:commandline).and_return commandline
    end

    context "running as CLI" do
      let(:commandline) { true }

      it "returns 0" do
        expect(subject.send(:display_width)).to eq 0
      end
    end

    context "running with full UI" do
      let(:commandline) { false }

      it "returns value from display info" do
        ui = double(GetDisplayInfo: { "Width" => 480 })
        stub_const("Yast::UI", ui)

        expect(subject.send(:display_width)).to eq 480
      end

      it "returns 0 if value missing in display info" do
        ui = double(GetDisplayInfo: {})
        stub_const("Yast::UI", ui)

        expect(subject.send(:display_width)).to eq 0
      end
    end
  end

  describe "#layout_popup" do
    it "returns yast term with popup content" do
      expect(subject.send(:layout_popup, "msg", ButtonBox(), true))
        .to be_a Yast::Term
    end

    it "write to Label passed message" do
      content = subject.send(:layout_popup, "msg", ButtonBox(), true)

      label = content.nested_find { |e| e == Label("msg") }

      expect(label).to_not eq nil
    end

    it "adds passed button box to content" do
      button_box = ButtonBox(PushButton("OK"))

      content = subject.send(:layout_popup, "msg", button_box, true)

      box = content.nested_find { |e| e == button_box }

      expect(box).to_not eq nil
    end

    it "tick checkbox for showing details depending on info_on parameter" do
      content1 = subject.send(:layout_popup, "msg", ButtonBox(), true)
      content2 = subject.send(:layout_popup, "msg", ButtonBox(), false)

      checkbox_find = proc { |e| e.is_a?(Yast::Term) && e.value == :CheckBox }

      checkbox1 = content1.nested_find(&checkbox_find)
      checkbox2 = content2.nested_find(&checkbox_find)

      expect(checkbox1.params.last).to eq true
      expect(checkbox2.params.last).to eq false
    end
  end

  describe "#progress_box" do
    it "returns yast term with box content" do
      expect(subject.send(:progress_box, "head", "aaa_base", "10MiB"))
        .to be_a Yast::Term
    end

    it "write to Heading passed heading parameter" do
      content = subject.send(:progress_box, "head", "aaa_base", "10MiB")

      heading = content.nested_find { |e| e == Heading("head") }

      expect(heading).to_not eq nil
    end

    it "adds passed name to Label" do
      content = subject.send(:progress_box, "head", "aaa_base", "10MiB")

      label = content.nested_find { |e| e == Label("aaa_base") }

      expect(label).to_not eq nil
    end

    it "adds passed sz to Label" do
      content = subject.send(:progress_box, "head", "aaa_base", "10MiB")

      label = content.nested_find { |e| e == Label("10MiB") }

      expect(label).to_not eq nil
    end
  end

  describe "retry_label" do
    it "returns localized string with text and passed timeout" do
      expect(subject.send(:retry_label, 15)).to be_a ::String
    end
  end

  describe "full_screen" do
    it "returns false if running in CLI" do
      allow(Yast::Mode).to receive(:commandline).and_return true

      expect(subject.send(:full_screen)).to eq false
    end

    # TODO: better description, but why it check this widget?
    it "returns if there is progress replace point" do
      allow(Yast::Mode).to receive(:commandline).and_return false
      ui = double(WidgetExists: true)
      stub_const("Yast::UI", ui)

      expect(subject.send(:full_screen)).to eq true
    end
  end

  describe "#cd_devices" do
    it "returns detected devices as list of Item terms" do
      allow(Yast::SCR).to receive(:Read).and_return(
        [
          { "dev_name" => "/dev/sr0", "model" => "Cool" },
          { "dev_name" => "/dev/sr1", "model" => "Less Cool" },
          { "dev_name" => "/dev/sr2", "model" => "Borring" }
        ]
      )

      expect(subject.send(:cd_devices, "/dev/sr0").size).to eq 3
      expect(subject.send(:cd_devices, "/dev/sr0").first).to be_a Yast::Term
      expect(subject.send(:cd_devices, "/dev/sr0").first.value).to eq :item
    end

    it "add special mark for preferred device" do
      allow(Yast::SCR).to receive(:Read).and_return(
        [
          { "dev_name" => "/dev/sr0", "model" => "Cool" },
          { "dev_name" => "/dev/sr1", "model" => "Less Cool" },
          { "dev_name" => "/dev/sr2", "model" => "Borring" }
        ]
      )
      cds = subject.send(:cd_devices, "/dev/sr0")

      found = cds.any? { |i| i.include? "\u27A4 Cool (/dev/sr0)" }

      expect(found).to eq true
    end

    it "return empty array if probing failed" do
      allow(Yast::SCR).to receive(:Read).and_return(nil)
      cds = subject.send(:cd_devices, "/dev/sr0")

      expect(cds).to eq []
    end
  end
end
