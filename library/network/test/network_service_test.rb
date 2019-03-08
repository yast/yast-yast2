#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "NetworkService"

describe Yast::NetworkService do
  context "smoke test" do
    describe "#is_network_manager" do
      it "does not crash" do
        expect { Yast::NetworkService.is_network_manager }.not_to raise_error
      end
    end

    describe "#is_wicked" do
      it "does not crash" do
        expect { Yast::NetworkService.is_wicked }.not_to raise_error
      end
    end

    describe "#is_netconfig" do
      it "does not crash" do
        expect { Yast::NetworkService.is_netconfig }.not_to raise_error
      end
    end

    describe "#EnableDisableNow" do
      it "does not crash when current / cached service is nil" do
        allow(Yast::NetworkService).to receive(:Modified).and_return(true)
        expect { Yast::NetworkService.EnableDisableNow }.not_to raise_error
      end
    end
  end

  describe "#RunSystemCtl" do
    it "shellescape properly all arguments" do
      expect(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        "/usr/bin/systemctl --force enable wicked.service",
        "TERM" => "raw")

      subject.RunSystemCtl("wicked", "enable", force: true)

      expect(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        "/usr/bin/systemctl  disable\\ \\|\\ evil wicked.service",
        "TERM" => "raw")

      subject.RunSystemCtl("wicked", "disable | evil")
    end
  end
end
