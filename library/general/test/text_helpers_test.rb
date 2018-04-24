#! /usr/bin/env rspec

require_relative "test_helper"

require "ui/text_helpers"

class TestTextHelpers
  include UI::TextHelpers
end

describe ::UI::TextHelpers do
  subject { TestTextHelpers.new }

  describe "#wrap_text" do
    let(:devices) { ["eth0", "eth1", "eth2", "eth3", "a_very_long_device_name"] }
    let(:more_devices) do
      [
        "enp5s0", "enp5s1", "enp5s2", "enp5s3",
        "enp5s4", "enp5s5", "enp5s6", "enp5s7"
      ]
    end

    context "given a text" do
      it "returns same text if it does not exceed the wrap size" do
        text = "eth0, eth1, eth2, eth3, a_very_long_device_name"

        expect(subject.wrap_text(devices.join(", "))).to eql(text)
      end

      context "and a line size" do
        it "returns given text splitted in lines by given line size" do
          text = "eth0, eth1, eth2,\n"     \
                 "eth3,\n"                 \
                 "a_very_long_device_name"

          expect(subject.wrap_text(devices.join(", "), 16)).to eql(text)
        end
      end

      context "and a number of lines and '...' as cut text" do
        it "returns wrapped text until given line's number adding '...' as a new line" do
          devices_s = (devices + more_devices).join(", ")
          text = "eth0, eth1, eth2,\n"        \
                 "eth3,\n"                    \
                 "a_very_long_device_name,\n" \
                 "..."

          expect(subject.wrap_text(devices_s, 20, n_lines: 3, cut_text: "...")).to eql(text)
        end
      end
    end
  end

  describe "#div_with_direction" do
    let(:language) { double("Yast::Language") }
    let(:lang) { "de_DE" }

    before do
      stub_const("Yast::Language", language)
      allow(language).to receive(:language).and_return(lang)
      allow(Yast).to receive(:import).with("Language")
    end

    context "when language is not 'arabic' or 'hebrew'" do
      let(:lang) { "de_DE" }

      it "wraps the text in a 'ltr' marker" do
        expect(subject.div_with_direction("sample"))
          .to eq("<div dir=\"ltr\">sample</div>")
      end
    end

    context "when current language is 'arabic'" do
      let(:lang) { "ar_AR" }

      it "wraps the text in a 'rtl' marker" do
        expect(subject.div_with_direction("sample"))
          .to eq("<div dir=\"rtl\">sample</div>")
      end
    end

    context "when current language is 'arabic'" do
      let(:lang) { "he_HE" }

      it "wraps the text in a 'rtl' marker" do
        expect(subject.div_with_direction("sample"))
          .to eq("<div dir=\"rtl\">sample</div>")
      end
    end

    context "when the language is specified as argument" do
      it "wraps the text according to the given language" do
        expect(subject.div_with_direction("sample", "ar_AR"))
          .to eq("<div dir=\"rtl\">sample</div>")
      end
    end

    context "when the text contains tags" do
      it "does not escape those tags" do
        expect(subject.div_with_direction("<strong>SAMPLE</strong>", "ar_AR"))
          .to eq("<div dir=\"rtl\"><strong>SAMPLE</strong></div>")
      end
    end
  end
end
