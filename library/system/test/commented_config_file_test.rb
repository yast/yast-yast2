#!/usr/bin/rspec
#
# Unit test for CommentedConfigFile
#
# (c) 2017 Stefan Hundhammer <Stefan.Hundhammer@gmx.de>
#     Donated to the YaST project
#
# Original project: https://github.com/shundhammer/ruby-commented-config-file
#
# License: GPL V2
#

require_relative "test_helper"
require "yast2/commented_config_file"

describe CommentedConfigFile do
  # rubocop:disable Lint/AmbiguousRegexpLiteral

  context "when created empty" do
    subject { described_class.new }

    describe "#new" do
      it "has no content" do
        expect(subject.header_comments).to be_nil
        expect(subject.footer_comments).to be_nil
        expect(subject.entries).to eq []
        expect(subject.filename).to be_nil
      end
    end

    describe "#header_comments?" do
      it "is false" do
        expect(subject.header_comments?).to eq false
      end
    end

    describe "#footer_comments?" do
      it "is false" do
        expect(subject.footer_comments?).to eq false
      end
    end
  end

  describe "#Entry.new" do
    let(:entry) { subject.create_entry }

    it "is empty" do
      expect(entry.content).to be_nil
      expect(entry.comment_before).to be_nil
      expect(entry.line_comment).to be_nil
      expect(entry.comment_before?).to eq false
      expect(entry.line_comment?).to eq false
    end

    it "has a parent" do
      expect(entry.parent).not_to be_nil
    end

    it "has the correct parent" do
      expect(entry.parent).to equal subject
    end
  end

  describe "#Entry.parse" do
    let(:ccf) { described_class.new }
    subject { ccf.create_entry }

    it "stores the content" do
      expect(subject.parse("foo = bar")).to eq true
      expect(subject.content).to eq "foo = bar"
    end
  end

  describe "#Entry.format" do
    let(:ccf) { described_class.new }
    subject { ccf.create_entry }

    it "formats the content without comments" do
      line = "foo bar baz"
      subject.parse(line)
      subject.line_comment = "line comment"
      subject.comment_before = "# comment\n# lines \n# before\n"
      expect(subject.format).to eq line
      expect(subject.to_s).to eq line
    end
  end

  context "Low-level parser" do
    describe "#comment_line?" do
      subject { described_class.new }

      context "with the default '#' comment marker" do
        it "Detects a simple comment line" do
          expect(subject.comment_line?("# foo")).to eq true
          expect(subject.comment_line?("#foo")).to eq true
        end

        it "Can handle leading whitespace" do
          expect(subject.comment_line?("  # foo")).to eq true
        end

        it "Can handle trailing whitespace" do
          expect(subject.comment_line?("# foo  \n")).to eq true
        end

        it "Rejects non-comment lines" do
          expect(subject.comment_line?("foo")).to eq false
          expect(subject.comment_line?("  foo")).to eq false
          expect(subject.comment_line?("foo # bar")).to eq false
          expect(subject.comment_line?("// foo")).to eq false
          expect(subject.comment_line?("")).to eq false
        end
      end

      context "with a custom '//' comment marker" do
        subject do
          ccf = described_class.new
          ccf.comment_marker = "//"
          ccf
        end

        it "Detects a simple comment line" do
          expect(subject.comment_line?("// foo")).to eq true
          expect(subject.comment_line?("//foo")).to eq true
        end

        it "Can handle leading whitespace" do
          expect(subject.comment_line?("  // foo")).to eq true
        end

        it "Can handle trailing whitespace" do
          expect(subject.comment_line?("// foo  \n")).to eq true
        end

        it "Rejects non-comment lines" do
          expect(subject.comment_line?("foo")).to eq false
          expect(subject.comment_line?("  foo")).to eq false
          expect(subject.comment_line?("foo # bar")).to eq false
          expect(subject.comment_line?("# foo")).to eq false
          expect(subject.comment_line?("")).to eq false
        end
      end
    end

    describe "#empty_line?" do
      subject { described_class.new }

      it "Detects a completely empty line" do
        expect(subject.empty_line?("")).to eq true
      end

      it "Detects lines with only whitespace " do
        expect(subject.empty_line?(" ")).to eq true
        expect(subject.empty_line?("  ")).to eq true
        expect(subject.empty_line?(" \n")).to eq true
        expect(subject.empty_line?("\t")).to eq true
        expect(subject.empty_line?("\t\n  \t\n")).to eq true
      end

      it "Rejects non-empty lines" do
        expect(subject.empty_line?("x")).to eq false
        expect(subject.empty_line?("  x")).to eq false
        expect(subject.empty_line?("  x  ")).to eq false
        expect(subject.empty_line?("  \nx  ")).to eq false
      end
    end

    describe "#split_off_comment" do
      subject { described_class.new }

      it "Splits a simple line with a comment correctly" do
        expect(subject.split_off_comment("foo = bar # baz")).to eq ["foo = bar", "# baz"]
      end

      it "Strips leading and trailing whitespace off the content" do
        expect(subject.split_off_comment("  foo =  bar   # baz")).to eq ["foo =  bar", "# baz"]
      end

      it "Leaves whitespace in the comment alone" do
        expect(subject.split_off_comment("foo = bar #  baz  ")).to eq ["foo = bar", "#  baz  "]
      end

      it "Handles lines without comments well" do
        expect(subject.split_off_comment("foo = bar")).to eq ["foo = bar", nil]
      end

      it "Handles comment lines without content well" do
        expect(subject.split_off_comment("# foo = bar")).to eq ["", "# foo = bar"]
        expect(subject.split_off_comment("   # foo = bar")).to eq ["", "# foo = bar"]
      end

      it "Handles empty lines well" do
        expect(subject.split_off_comment("")).to eq ["", nil]
      end
    end
  end

  context "High-level parser" do
    describe "#parse" do
      context "Demo /etc/fstab with header and footer comments" do
        before(:all) do
          @file = described_class.new
          @file.read(TEST_DATA + "fstab/demo-fstab")
        end
        subject { @file }

        it "Has the correct header comments" do
          header = subject.header_comments
          expect(header.size).to eq 15
          expect(header[0]).to match /static file system information/
          expect(header[-2]).to match /mount point.*type.*dump.*pass/
          expect(header[-1]).to match /^\s*$/
        end

        it "Has the correct footer comments" do
          footer = subject.footer_comments
          expect(footer.size).to eq 1
          expect(footer[0]).to match /^\s*$/
        end

        it "Has the correct number of entries" do
          expect(subject.size).to eq 9
        end

        it "The first entry is correct" do
          entry = subject.first
          expect(entry.content).to match /by-label\/swap\s+none\s+swap/
          expect(entry.comment_before.size).to eq 1
          expect(entry.comment_before.first).to match /Linux disk/
        end

        it "The root filesystem entry is correct" do
          entry = subject.entries[2]
          expect(entry.content).to match /Ubuntu.*ext4.*errors=remount-ro/
          expect(entry.comment_before?).to eq false
          expect(entry.line_comment?).to eq false
        end

        it "The last entry is correct" do
          entry = subject.last
          expect(entry.content).to match /fritz.box.fritz.nas.*cifs.*forcegid/
          expect(entry.comment_before.first).to match /^\s*$/
        end
      end

      context "Demo /etc/fstab without header and footer comments" do
        before(:all) do
          @file = described_class.new
          puts("TEST_DATA: #{TEST_DATA}")
          @file.read(TEST_DATA + "fstab/demo-fstab-no-header")
        end
        subject { @file }

        it "Does not have header comments" do
          expect(subject.header_comments?).to eq false
        end

        it "Does not have footer comments" do
          expect(subject.footer_comments?).to eq false
        end

        it "Has the correct number of entries" do
          expect(subject.size).to eq 9
        end

        it "The first entry is correct" do
          entry = subject.first
          expect(entry.content).to match /by-label\/swap\s+none\s+swap/
          expect(entry.comment_before?).to eq false
        end

        it "The root filesystem entry is correct" do
          entry = subject.entries[2]
          expect(entry.content).to match /Ubuntu.*ext4.*errors=remount-ro/
          expect(entry.comment_before?).to eq false
          expect(entry.line_comment?).to eq false
        end

        it "The last entry is correct" do
          entry = subject.last
          expect(entry.content).to match /fritz.box.fritz.nas.*cifs.*forcegid/
          expect(entry.comment_before.first).to match /^\s*$/
        end
      end
    end
  end

  context "Formatter" do
    describe("#format_lines") do
      def read_twice(filename)
        orig = File.read(filename).chomp
        file = described_class.new
        file.read(filename)
        formatted = file.to_s
        [orig, formatted]
      end

      it "reproduces exactly the original format with header and footer" do
        orig, formatted = read_twice(TEST_DATA + "fstab/demo-fstab")
        expect(formatted).to eq orig
      end

      it "reproduces exactly the original format without header or footer" do
        orig, formatted = read_twice(TEST_DATA + "fstab/demo-fstab-no-header")
        expect(formatted).to eq orig
      end

      it "reproduces exactly the original format for demo-sudoers" do
        orig, formatted = read_twice(TEST_DATA + "fstab/demo-sudoers")
        expect(formatted).to eq orig
      end
    end
  end
end
