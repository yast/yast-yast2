#! /usr/bin/env rspec

require_relative "test_helper"

require "ui/text_helpers"

class TestTextHelpers
  include UI::TextHelpers
end

describe ::UI::TextHelpers do
  subject { TestTextHelpers.new }
  let(:text) do
    "This is a long paragraph.
    It contains a not_real_but_really_long_word which must not be broken
    and the length of its longer lines is a little git greater than the default line width.
    Let's see if it's work."
  end

  describe "#wrap_text" do
    context "when the text does not exceed the line width" do
      let(:text) { "A very short text." }

      it "returns the same text" do
        expect(subject.wrap_text(text)).to eq(text)
      end

      context "but a prepend text is given" do
        let(:prepend_text) { "This is: " }

        it "includes the prepend text" do
          expect(subject.wrap_text(text, prepend_text: prepend_text)).to match(/^This is/)
        end

        context "and both of them exceed the line width" do
          it "returns wrapped text" do
            wrapped_text = subject.wrap_text(text, 15, prepend_text: prepend_text)

            expect(wrapped_text.lines.size).to eq(2)
          end
        end
      end
    end

    context "when the text exceed the given line width" do
      it "produces a text with lines no longer than given line width" do
        line_width = 60
        wrapped_text = subject.wrap_text(text, line_width)

        expect(wrapped_text.lines.map(&:length)).to all(be < line_width)
      end

      it "respect present carriage returns" do
        current_lines = text.lines.size

        expect(subject.wrap_text(text).lines.size).to be > current_lines
      end

      it "does not break words" do
        wrapped_text = subject.wrap_text(text)

        expect(wrapped_text).to match(/it\'s/)
        expect(wrapped_text).to match(/not_real_but_really_long_word/)
      end

      context "and a prepend text is given" do
        let(:prepend_text) { "This is: " }

        it "includes the prepend text" do
          expect(subject.wrap_text(text, prepend_text: prepend_text)).to match(/^This is/)
        end
      end

      context "and a max number of lines is set (n_lines)" do
        it "returns only the first n_lines" do
          wrapped_text = subject.wrap_text(text, n_lines: 2)

          expect(wrapped_text.lines.size).to eq(2)
          expect(wrapped_text).to match(/^This is/)
          expect(wrapped_text).to match(/broken$/)
        end

        context "with an ommission text (cut_text)" do
          it "includes an additional line with the cut_text" do
            omission = "..."
            wrapped_text = subject.wrap_text(text, n_lines: 2, cut_text: omission)

            expect(wrapped_text.lines.size).to eq(3)
            expect(wrapped_text).to match(/^This is/)
            expect(wrapped_text.lines.last).to eq("...")
          end
        end
      end
    end
  end

  describe "#head" do
    let(:omission_text) { "read more" }

    context "when the text has less lines than requested" do
      it "returns the full text" do
        expect(subject.head(text, 10)).to eq(text)
      end

      context "and the omision text is given" do
        it "does not include the omission text" do
          expect(subject.head(text, 10, omission: omission_text)).to_not include(omission_text)
        end
      end
    end

    context "when the text has more lines than requested" do
      it "returns only the first requested lines" do
        head = subject.head(text, 2)

        expect(head.lines.size).to eq(2)
        expect(head).to match(/^This is/)
        expect(head).to match(/broken$/)
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

    context "when current language is 'hebrew'" do
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
