#! /usr/bin/env rspec

require_relative "test_helper"

require "cwm/common_widgets"
require "cwm/rspec"

describe CWM::RadioButtons do
  class TestRadioButtons < CWM::RadioButtons
    def label
      "Choose a number"
    end

    def items
      [[:one, "One"], [:two, "Two"], [:three, "Three"]]
    end
  end

  class TestSpacedRadioButtons < TestRadioButtons
    def vspacing
      2
    end

    def hspacing
      3
    end
  end

  describe "#cwm_definition" do
    context "if #vspacing and #hspacing are not defined" do
      subject { TestRadioButtons.new }

      it "does not include the vspacing key" do
        expect(subject.cwm_definition.keys).to_not include("vspacing")
      end

      it "does not include the hspacing key" do
        expect(subject.cwm_definition.keys).to_not include("hspacing")
      end
    end

    context "if #vspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets vspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("vspacing")
        expect(subject.cwm_definition["vspacing"]).to eq 2
      end
    end

    context "if #hspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets hspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("hspacing")
        expect(subject.cwm_definition["hspacing"]).to eq 3
      end
    end
  end
end

describe CWM::RichText do
  subject { described_class.new }
  let(:widget_id) { Id(subject.widget_id) }
  let(:new_content) { "Updated content" }
  let(:vscroll) { "40" }

  describe "#value=" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(widget_id, :VScrollValue).and_return(vscroll)
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    context "when set to keep the scroll" do
      before do
        allow(subject).to receive(:keep_scroll?).and_return(true)
      end

      it "changes the widget value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, new_content)

        subject.value = new_content
      end

      it "saves vertical scroll position" do
        expect(Yast::UI).to receive(:QueryWidget).with(widget_id, :VScrollValue)

        subject.value = new_content
      end

      it "restores vertical scroll" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :VScrollValue, vscroll)

        subject.value = new_content
      end
    end

    context "when set to not keep the scroll" do
      it "changes the widget value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, new_content)

        subject.value = new_content
      end

      it "does not restore the scroll" do
        expect(Yast::UI).to_not receive(:ChangeWidget).with(widget_id, :VScrollValue, anything)

        subject.value = new_content
      end
    end
  end
end

describe CWM::ComboBox do
  class MountPointSelector < CWM::ComboBox
    def label
      ""
    end

    def opt
      [:editable]
    end

    def items
      [["/", "/ (root)"]]
    end
  end

  subject { MountPointSelector.new }

  describe "#value=" do
    describe "when the widget is editable" do
      it "adds the given value to the list of items" do
        expect(subject).to receive(:change_items).with([["/srv", "/srv"], ["/", "/ (root)"]])
        subject.value = "/srv"
      end
    end
  end
end
