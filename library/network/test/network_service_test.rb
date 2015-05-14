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
  end
end
