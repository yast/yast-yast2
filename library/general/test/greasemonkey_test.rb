#! /usr/bin/env rspec
require_relative "test_helper"
require "ui/greasemonkey"

describe "UI::Greasemonkey" do
  RSpec.shared_examples "a Greasemonkey method" do |mname|
    it "transforms its argument properly" do
      expect(UI::Greasemonkey.public_send(mname, old)).to eq new
    end
  end

  describe ".VStackFrames" do
    let(:old) do
      term(
        :VStackFrames,
        Frame("f1"),
        Frame("f2"),
        Frame("f3")
      )
    end
    let(:new) do
      VBox(
        Frame("f1"),
        VSpacing(0.45),
        Frame("f2"),
        VSpacing(0.45),
        Frame("f3")
      )
    end
    it_behaves_like "a Greasemonkey method", :VStackFrames
  end

  describe ".FrameWithMarginBox" do
    let(:old) { term(:FrameWithMarginBox, "Title", "arg1", "arg2") }
    let(:new) { Frame("Title", MarginBox(1.45, 0.45, "arg1", "arg2")) }
    it_behaves_like "a Greasemonkey method", :FrameWithMarginBox
  end

  describe ".ComboBoxSelected" do
    let(:old) do
      term(
        :ComboBoxSelected,
        Id(:wish), Opt(:notify), "Wish",
        [
          Item(Id(:time), "Time"),
          Item(Id(:love), "Love"),
          Item(Id(:money), "Money")
        ],
        Id(:love)
      )
    end
    let(:new) do
      ComboBox(
        Id(:wish), Opt(:notify), "Wish",
        [
          Item(Id(:time), "Time", false),
          Item(Id(:love), "Love", true),
          Item(Id(:money), "Money", false)
        ]
      )
    end
    it_behaves_like "a Greasemonkey method", :ComboBoxSelected
  end

  describe ".LeftRadioButton" do
    let(:old) { term(:LeftRadioButton, "some", "args") }
    let(:new) { Left(RadioButton("some", "args")) }
    it_behaves_like "a Greasemonkey method", :LeftRadioButton
  end

  describe ".LeftRadioButtonWithAttachment" do
    let(:old) { term(:LeftRadioButtonWithAttachment, "foo", "bar", "contents") }
    let(:new) do
      VBox(
        # NOTE that it does not expand this Greasemonkey term!
        term(:LeftRadioButton, "foo", "bar"),
        HBox(HSpacing(4), "contents")
      )
    end
    it_behaves_like "a Greasemonkey method", :LeftRadioButtonWithAttachment

    it "discards the attachment when it is Empty()" do
      old = term(:LeftRadioButtonWithAttachment, "foo", "bar", Empty())
      new = VBox(term(:LeftRadioButton, "foo", "bar"))
      expect(UI::Greasemonkey.LeftRadioButtonWithAttachment(old)).to eq new
    end
  end

  describe ".LeftCheckBox" do
    let(:old) { term(:LeftCheckBox, "some", "args") }
    let(:new) { Left(CheckBox("some", "args")) }
    it_behaves_like "a Greasemonkey method", :LeftCheckBox
  end

  describe ".LeftCheckBoxWithAttachment" do
    let(:old) { term(:LeftCheckBoxWithAttachment, "foo", "bar", "contents") }
    let(:new) do
      VBox(
        # NOTE that it does not expand this Greasemonkey term!
        term(:LeftCheckBox, "foo", "bar"),
        HBox(HSpacing(4), "contents")
      )
    end
    it_behaves_like "a Greasemonkey method", :LeftCheckBoxWithAttachment

    it "discards the attachment when it is Empty()" do
      old = term(:LeftCheckBoxWithAttachment, "foo", "bar", Empty())
      new = VBox(term(:LeftCheckBox, "foo", "bar"))
      expect(UI::Greasemonkey.LeftCheckBoxWithAttachment(old)).to eq new
    end
  end

  describe ".IconAndHeading" do
    let(:old) { term(:IconAndHeading, "title", "icon") }
    let(:new) do
      Left(
        HBox(
          Image("/usr/share/YaST2/theme/current/icons/22x22/apps/icon", ""),
          Heading("title")
        )
      )
    end
    it_behaves_like "a Greasemonkey method", :IconAndHeading
  end

  describe ".transform" do
    it "transforms the term recursively" do
      old = term(
        :FrameWithMarginBox,
        "Title",
        VBox(
          term(:LeftRadioButton, "arg1"),
          VSpacing(3),
          term(:LeftRadioButton, "arg2")
        )
      )
      new = Frame(
        "Title",
        MarginBox(
          1.45, 0.45,
          VBox(
            Left(RadioButton("arg1")),
            VSpacing(3),
            Left(RadioButton("arg2"))
          )
        )
      )
      expect(UI::Greasemonkey.transform(old)).to eq new
    end
  end
end
