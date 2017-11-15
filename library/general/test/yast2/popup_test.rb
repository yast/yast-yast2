#! /usr/bin/env rspec

require_relative "../test_helper"
require "erb"

require "yast2/popup"

describe Yast2::Popup do
  let(:ui) { double("Yast::UI") }
  subject { Yast2::Popup }

  before do
    # generic UI stubs
    stub_const("Yast::UI", ui)
  end

  describe ".update_feedback" do
    it "modifies feedback message" do
      expect(ui).to receive(:ChangeWidget).with(anything, :Value, "test")

      subject.update_feedback("test")
    end
  end

  describe ".stop_feedback" do
    it "closes dialog with feedback" do
      allow(ui).to receive(:WidgetExists).and_return(true)
      expect(ui).to receive(:CloseDialog)

      subject.stop_feedback
    end

    it "raises runtime error if feedback is not opened previously" do
      allow(ui).to receive(:WidgetExists).and_return(false)
      expect { subject.stop_feedback }.to raise_error(RuntimeError)
    end
  end

  describe ".start_feedback" do
    it "opens dialog" do
      allow(ui).to receive(:OpenDialog).and_return(true)

      subject.start_feedback("test")
    end

    it "raises ArgumentError if message is not string" do
      expect { subject.start_feedback(nil) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError if headline is not string" do
      expect { subject.start_feedback("test", headline: nil) }.to raise_error(ArgumentError)
    end

    it "raises RuntimeError if dialogs fails to open" do
      allow(ui).to receive(:OpenDialog).and_return(false)

      expect { subject.start_feedback("test") }.to raise_error(RuntimeError)
    end

    it "contains heading if headline is non-empty" do
      allow(ui).to receive(:OpenDialog) do |arg|
        expect(arg.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Heading }).to be_a(Yast::Term)
        true
      end

      subject.start_feedback("test", headline: "head")
    end

    it "does not contain heading if headline is empty" do
      allow(ui).to receive(:OpenDialog) do |arg|
        expect(arg.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Heading }).to eq nil
        true
      end

      subject.start_feedback("test", headline: "")
    end
  end

  describe ".show" do
    before do
      allow(ui).to receive(:OpenDialog).and_return(true)
      allow(ui).to receive(:SetFocus)
      allow(ui).to receive(:CloseDialog)
      allow(ui).to receive(:UserInput).and_return(:cancel)
    end

    it "shows message" do
      expect(ui).to receive(:OpenDialog) do |_opts, content|
        expect(content.nested_find { |w| w == "test" }).to_not eq nil

        true
      end

      subject.show("test")
    end

    context "details parameter is not empty" do
      it "shows details button" do
        expect(ui).to receive(:OpenDialog) do |_opts, content|
          widget = content.nested_find do |w|
            w.is_a?(Yast::Term) &&
              w.value == :PushButton &&
              w.params.include?("&Details...")
          end
          expect(widget).to_not eq nil

          true
        end

        subject.show("test", details: "more tests")
      end

      it "opens additional dialog when clicked on details" do
        expect(ui).to receive(:UserInput).and_return(:__details, :cancel, :cancel)

        expect(ui).to receive(:OpenDialog).and_return(true).twice

        subject.show("test", details: "more tests")
      end
    end
  end
end
