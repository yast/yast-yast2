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
      expect(subject.UnQuote("a'\\'''\\''b'\\''c")).to eq "a''b'c"
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
      -1_049_000            => "-1 MiB", # FIXME: why?
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

  describe ".Pad" do
    it "Adds spaces after text to have it long as length" do
      expect(subject.Pad("test", 5)).to eq "test "
      expect(subject.Pad("test", 4)).to eq "test"
      expect(subject.Pad("test ", 7)).to eq "test   "
    end

    it "Returns text if length is negative or zero" do
      expect(subject.Pad("test", -1)).to eq "test"
      expect(subject.Pad("test", 0)).to eq "test"
    end

    it "Returns string full of spaces length long if text is nil or empty" do
      expect(subject.Pad("", 5)).to eq "     "
      expect(subject.Pad(nil, 5)).to eq "     "
    end
  end

  describe ".PadZeros" do
    it "Adds zeros before text to have it long as length" do
      expect(subject.PadZeros("1", 5)).to eq "00001"
      expect(subject.PadZeros("12", 5)).to eq "00012"
      expect(subject.PadZeros("12345", 5)).to eq "12345"
    end

    it "Returns text if length is negative or zero" do
      expect(subject.PadZeros("12", -1)).to eq "12"
      expect(subject.PadZeros("12", 0)).to eq "12"
    end

    it "Returns string full of zeros length long if text is nil or empty" do
      expect(subject.PadZeros("", 5)).to eq "00000"
      expect(subject.PadZeros(nil, 5)).to eq "00000"
    end
  end

  describe ".ParseOptions" do
    it "parse key=value map separated by space or tab by default" do
      expect(subject.ParseOptions("a=3\tb=2", {})).to eq ["a=3", "b=2"]
      expect(subject.ParseOptions("a=3 b=2", {})).to eq ["a=3", "b=2"]
      expect(subject.ParseOptions("a=", {})).to eq ["a="]
    end

    it "allows to specify as separator different value" do
      expect(subject.ParseOptions("a=3,b=2", "separator" => ",")).to eq ["a=3", "b=2"]
    end

    it "allows to specify if values should be unique" do
      expect(subject.ParseOptions("1 1 2", "unique" => false)).to eq ["1", "1", "2"]
      expect(subject.ParseOptions("1 1 2", "unique" => true)).to eq ["1", "2"]
    end

    it "allows to specify if additional whitespaces should be removed" do
      expect(subject.ParseOptions(" 1 ,  2", "remove_whitespace" => true, "separator" => ",")).to eq ["1", "2"]
      expect(subject.ParseOptions(" 1 ,  2", "remove_whitespace" => false, "separator" => ",")).to eq [" 1 ", "  2"]
    end

    it "allows to specify if backslash should be interpreted" do
      expect(subject.ParseOptions("a=\\n", "interpret_backslash" => true)).to eq ["a=\n"]
      expect(subject.ParseOptions("a=\\n", "interpret_backslash" => false)).to eq ["a=\\n"]
    end

    it "returns empty array if nil passed as options" do
      expect(subject.ParseOptions(nil, {})).to eq []
    end

    it "returns empty array if empty string passed as options" do
      expect(subject.ParseOptions("", {})).to eq []
    end

    it "returns empty array if string containing only separator passed as options" do
      expect(subject.ParseOptions("  \t  ", {})).to eq []
    end
  end

  describe ".CutRegexMatch" do
    it "returns string with first match of given regexp removed when glob is set to false" do
      expect(subject.CutRegexMatch("ab123cd56", "[0-9]+", false)).to eq "abcd56"
    end

    it "returns string with all matches of given regexp removed when glob is set to true" do
      expect(subject.CutRegexMatch("ab123cd56", "[0-9]+", true)).to eq "abcd"
    end

    it "returns input when no match of regex found" do
      expect(subject.CutRegexMatch("ab123cd56", "[A-Z]+", false)).to eq "ab123cd56"
    end

    it "returns empty string if input is nil" do
      expect(subject.CutRegexMatch(nil, "[A-Z]+", false)).to eq ""
    end

    it "returns input if regex is nil" do
      expect(subject.CutRegexMatch("ab123cd56", nil, false)).to eq "ab123cd56"
    end
  end

  describe ".EscapeTags" do
    it "escapes html/xml tags" do
      expect(subject.EscapeTags("<font size='2'><b>text & another</b></font>")).to eq(
        "&lt;font size='2'&gt;&lt;b&gt;text &amp; another&lt;/b&gt;&lt;/font&gt;"
      )
    end

    it "returns nil if nil passed" do
      expect(subject.EscapeTags(nil)).to eq nil
    end
  end

  describe ".StartsWith" do
    it "checks if string str start with string test" do
      expect(subject.StartsWith("Hello world", "Hello")).to eq true
      expect(subject.StartsWith("Hello", "Hello")).to eq true
      expect(subject.StartsWith("Hello", "hello")).to eq false
      expect(subject.StartsWith("Hello", "World")).to eq false
    end

    it "returns false if str is nil" do
      expect(subject.StartsWith(nil, "hello")).to eq false
    end

    it "returns false if test is nil" do
      expect(subject.StartsWith("hello", nil)).to eq false
    end

    it "returns false if both params are nil" do
      expect(subject.StartsWith(nil, nil)).to eq false
    end
  end

  describe ".RemoveShortcut" do
    it "returns string with removed a UI key shortcuts from label" do
      expect(subject.RemoveShortcut("Hello")).to eq "Hello"
      expect(subject.RemoveShortcut("&Hello")).to eq "Hello"
      expect(subject.RemoveShortcut("He&llo")).to eq "Hello"
      expect(subject.RemoveShortcut("&He&llo")).to eq "&Hello" # FIXME: Why? this looks like bug
      expect(subject.RemoveShortcut("&&He&llo")).to eq "&&Hello"
      expect(subject.RemoveShortcut("&&Hello")).to eq "&&Hello"
      expect(subject.RemoveShortcut("&&&Hello")).to eq "&&Hello"
      expect(subject.RemoveShortcut("&&&&Hello")).to eq "&&&&Hello"
    end

    it "returns nil if label is nil" do
      expect(subject.RemoveShortcut(nil)).to eq nil
    end
  end

  describe ".ReplaceWith" do
    it "returns string with all characters in chars replaced by glue" do
      expect(subject.ReplaceWith("a\nb\tc d", "\n\t ", "-")).to eq "a-b-c-d"
      expect(subject.ReplaceWith("a\nb\tc d", "\n\t ", "")).to eq "abcd"
    end

    it "returns nil if str is nil" do
      expect(subject.ReplaceWith(nil, " ", "")).to eq nil
    end

    it "returns nil if chars is nil" do
      expect(subject.ReplaceWith("abc", nil, "")).to eq nil
    end

    it "returns nil if glue is nil" do
      expect(subject.ReplaceWith("abc", "a", nil)).to eq nil
      expect(subject.ReplaceWith("abc", "d", nil)).to eq nil
    end
  end
end
