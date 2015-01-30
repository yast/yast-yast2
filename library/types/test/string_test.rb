#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "String"

describe Yast::String do
  before do
    # ensure proper default locale
    ENV["LANG"] = "C"
  end

  describe ".Quote" do
    it "returns empty string if nil passed" do
      expect(subject.Quote(nil)).to eq ""
    end

    it "returns all single quotes escaped" do
      expect(subject.Quote("")).to eq ""
      expect(subject.Quote("a")).to eq "a"
      expect(subject.Quote("a'b")).to eq "a'\\''b"
      expect(subject.Quote("a'b'c")).to eq "a'\\''b'\\''c"
    end
  end

  describe ".UnQuote" do
    it "returns empty string if nil passed" do
      expect(subject.UnQuote(nil)).to eq ""
    end

    it "returns unescaped single quotes" do
      expect(subject.UnQuote("")).to eq ""
      expect(subject.UnQuote("a")).to eq "a"
      expect(subject.UnQuote("a'\\''b")).to eq "a'b"
      expect(subject.UnQuote("a'\\''b'\\''c")).to eq "a'b'c"
    end
  end

  describe ".FormatSize" do
    it "returns empty string if nil passed" do
      expect(subject.FormatSize(nil)).to eq ""
    end

    FORMAT_SIZE_DATA = {
      0                     => "0 B",
      1                     => "1 B",
      1025                  => "1 KiB",
      1125                  => "1.1 KiB",
      743 * 1024            => "743 KiB",
      1_049_000             => "1.00 MiB",
      1_074_000_000         => "1.000 GiB",
      1_100_000_000_000     => "1.000 TiB",
      1_126_000_000_000_000 => "1024.091 TiB",
      1 << 10               => "1 KiB",
      1 << 20               => "1.00 MiB",
      1 << 30               => "1.000 GiB",
      1 << 40               => "1.000 TiB"
    }

    it "returns size formatted with proper bytes units" do
      FORMAT_SIZE_DATA.each do |arg, res|
        expect(subject.FormatSize(arg)).to eq res
      end
    end
  end

  describe ".FormatSizeWithPrecision" do
    it "returns empty string if nil passed" do
      expect(subject.FormatSizeWithPrecision(nil, nil, nil)).to eq ""
    end

    it "returns bytes in proper unit with passed precision forcing trailing zeroes if omit_zeroes not passed" do
      expect(subject.FormatSizeWithPrecision(1025 << 30, 2, false)).to eq "1.00 TiB"
      expect(subject.FormatSizeWithPrecision(1025 << 30, 3, false)).to eq "1.001 TiB"
    end

    it "returns bytes with precision based on suffix if negative precision passed" do
      expect(subject.FormatSizeWithPrecision(1025 << 30, -1, false)).to eq "1.001 TiB"
      expect(subject.FormatSizeWithPrecision(1025, -1, false)).to eq "1.0 KiB"
    end

    it "omit trailing zeros if omit_zeroes is passed as true" do
      expect(subject.FormatSizeWithPrecision(4097, 2, true)).to eq "4 KiB"
      expect(subject.FormatSizeWithPrecision(1 << 20, 2, true)).to eq "1 MiB"
      expect(subject.FormatSizeWithPrecision(1025, 2, true)).to eq "1 KiB"
      expect(subject.FormatSizeWithPrecision(8 << 30, 2, true)).to eq "8 GiB"
    end
  end

  describe ".CutBlanks" do
    it "return empty string for nil" do
      expect(subject.CutBlanks(nil)).to eq ""
    end

    CUT_BLANKS_DATA = {
      ""              => "",
      "abc"           => "abc",
      " abc"          => "abc",
      "abc "          => "abc",
      " abc "         => "abc",
      "\tabc "        => "abc",
      "\tabc\t "      => "abc",
      " \tabc\t "     => "abc",
      "\t a b c \t"   => "a b c",
      "\t a b c \t\n" => "a b c \t\n"
    }
    it "remove trailing and prepending whitespace" do
      CUT_BLANKS_DATA.each do |arg, res|
        expect(subject.CutBlanks(arg)).to eq res
      end
    end
  end

  describe ".CutZeros" do
    it "return empty string for nil" do
      expect(subject.CutZeros(nil)).to eq ""
    end

    CUT_ZEROS_DATA = {
      ""    => "",
      "1"   => "1",
      "01"  => "1",
      "001" => "1",
      "0"   => "0",
      "00"  => "0"
    }
    it "removes prepended zeros" do
      CUT_ZEROS_DATA.each do |arg, res|
        expect(subject.CutZeros(arg)).to eq res
      end
    end
  end

  describe ".Repeat" do
    it "returns empty string is nil passed as text" do
      expect(subject.Repeat(nil, 5)).to eq ""
    end

    it "returns empty string if nil passed as number" do
      expect(subject.Repeat("a", nil)).to eq ""
    end

    it "returns empty string if number is zero or negative" do
      expect(subject.Repeat("a", 0)).to eq ""
      expect(subject.Repeat("a", -1)).to eq ""
    end

    it "returns string text repeated number times" do
      expect(subject.Repeat("a", 5)).to eq "aaaaa"
    end
  end

  describe ".SuperPad" do
    it "returns length times repeated padding if nil is passed as text" do
      expect(subject.SuperPad(nil, 5, ".", :right)).to eq "....."
    end

    it "returns text if is nil passed as padding" do
      expect(subject.SuperPad("test", 5, nil, :right)).to eq "test"
    end

    it "returns text if is nil is passed as lenght" do
      expect(subject.SuperPad("test", nil, ".", :right)).to eq "test"
    end

    it "returns text prefixed by padding to make lenght requested if alignment is :right" do
      expect(subject.SuperPad("test", 5, ".", :right)).to eq ".test"
    end

    it "returns text suffixed by padding to make lenght requested if alignment is not :right" do
      expect(subject.SuperPad("test", 5, ".", :left)).to eq "test."
    end
  end
end
