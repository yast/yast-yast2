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

  describe "#plain_text" do
    let(:text) { "<p>YaST:</p><p>a <b>powerful</b> installation and <em>configuration</em> tool.</p>" }

    context "when neither tags: nor replacements: are given" do
      it "replaces tags with default replacements" do
        expect(subject.plain_text(text))
          .to eq("YaST:\n\na powerful installation and configuration tool.")
      end
    end

    context "when the tag list is given" do
      let(:tags) { ["p", "em"] }

      it "changes only the specified tags" do
        expect(subject.plain_text(text, tags: tags))
          .to eq("YaST:\n\na <b>powerful</b> installation and configuration tool.")
      end

      context "and a list of replacements is provided too" do
        let(:replacements) do
          { "<b>" => "*", "</b>" => "*", "<em>" => "_", "</em>" => "_" }
        end

        it "keeps unmatched tags" do
          expect(subject.plain_text(text, tags: tags, replacements: replacements))
            .to match(/a <b>powerful<\/b> installation/)
        end

        it "deletes matched tags without replacements" do
          expect(subject.plain_text(text, tags: tags, replacements: replacements))
            .to_not match(/<p>.*<\/p>/)
        end

        it "replaces matched tags with replacements" do
          expect(subject.plain_text(text, tags: tags, replacements: replacements))
            .to match(/and _configuration_ tool/)
        end
      end
    end

    context "when the list of replacements is given" do
      let(:replacements) do
        { "<b>" => "*", "</b>" => "*", "<em>" => "_", "</em>" => "_", "<p>" => "\n> " }
      end

      it "replaces matched tags using given replacements" do
        expect(subject.plain_text(text, replacements: replacements))
          .to eq("> YaST:\n> a *powerful* installation and _configuration_ tool.")
      end

      context "and a list of tags is provided too" do
        let(:tags) { ["b"] }

        it "keeps unmatched tags" do
          expect(subject.plain_text(text, tags: tags, replacements: replacements))
            .to match(/<p>.*and <em>configuration<\/em> tool.<\/p>/)
        end

        it "replaces matched tags with replacements" do
          expect(subject.plain_text(text, tags: tags, replacements: replacements))
            .to match(/a \*powerful\* installation/)
        end
      end
    end
  end

end
