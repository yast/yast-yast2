#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "Arch"

require "yast"

describe Yast::Arch do

  describe ".is_zkvm" do
    before do
      # need to reset all initializeation of the module for individual
      # test cases which mock different hardware
      # otherwise values in Arch.rb remain cached
      module_path = File.expand_path("../src/modules/Arch.rb", __dir__)
      load module_path
    end

    it "returns true if on s390 and in the zKVM environment" do
      allow(Yast::WFM).to receive(:Execute).and_return 0
      allow(Yast::SCR).to receive(:Read).and_return "s390_64"

      is_zkvm = Yast::Arch.is_zkvm

      expect(is_zkvm).to eq(true)
    end

    it "returns false if on s390 and not in the zKVM environment" do
      allow(Yast::WFM).to receive(:Execute).and_return 1
      allow(Yast::SCR).to receive(:Read).and_return "s390_64"

      is_zkvm = Yast::Arch.is_zkvm

      expect(is_zkvm).to eq(false)
    end

    it "returns false on other architectures" do
      allow(Yast::WFM).to receive(:Execute).and_return 0
      allow(Yast::SCR).to receive(:Read).and_return "x86_64"

      is_zkvm = Yast::Arch.is_zkvm

      expect(is_zkvm).to eq(false)
    end
  end

  describe ".is_wsl" do
    before do
      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.string"), "/proc/sys/kernel/osrelease")
        .and_return(osrelease)
    end

    context "when it runs on a Microsoft kernel" do
      let(:osrelease) { "5.3.11-Microsoft" }

      it "returns true" do
        expect(Yast::Arch.is_wsl).to eq(true)
      end
    end

    context "when it does not run on a Microsoft kernel" do
      let(:osrelease) { "5.3.11-default" }

      it "returns false" do
        expect(Yast::Arch.is_wsl).to eq(false)
      end
    end
  end
end
