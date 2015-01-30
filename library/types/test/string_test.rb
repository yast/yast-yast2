#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "String"

describe Yast::String do
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
end
