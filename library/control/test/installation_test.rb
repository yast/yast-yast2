#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "Installation"

describe Yast::Installation do
  subject { Yast::Installation }

  describe ".sourcedir" do
    before do
      allow(::File).to receive(:exist?).and_return(true)
    end

    it "returns string" do
      expect(subject.sourcedir).to eq "/run/YaST2/mount"
    end

    it "ensures that directory exists" do
      expect(::File).to receive(:exist?).and_return(false)
      expect(::FileUtils).to receive(:mkdir_p)

      subject.sourcedir
    end
  end
end
