#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackageCallbacks"

describe Yast::PackageCallbacks do
  subject { Yast::PackageCallbacks }

  describe "#textmode" do
    it "returns if runned as CLI" do
      mode = double(:commandline => true )
      stub_const("Yast::Mode", mode)

      expect(subject.send(:textmode)).to eq true
    end

    it "returns if running in TUI" do
      ui = double(:GetDisplayInfo => { "TextMode" => true })
      stub_const("Yast::UI", ui)

      expect(subject.send(:textmode)).to eq true
    end

    it "returns false in other cases" do
      ui = double(:GetDisplayInfo => { "TextMode" => false })
      stub_const("Yast::UI", ui)

      expect(subject.send(:textmode)).to eq false
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

      checkbox_find = Proc.new { |e| e.is_a?(Yast::Term) && e.value == :CheckBox }

      checkbox1 = content1.nested_find(&checkbox_find)
      checkbox2 = content2.nested_find(&checkbox_find)

      expect(checkbox1.params.last).to eq true
      expect(checkbox2.params.last).to eq false
    end
  end
end
