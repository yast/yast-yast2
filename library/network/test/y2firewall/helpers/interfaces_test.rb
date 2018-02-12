#!/usr/bin/env rspec

require_relative "../../test_helper"
require "y2firewall/helpers/interfaces"

class DummyClass
  include Y2Firewall::Helpers::Interfaces
end

describe Y2Firewall::Helpers::Interfaces do
  subject { DummyClass.new }

  before do
    allow(Yast::NetworkInterfaces).to receive("List").and_return(["eth0", "eth1"])
    allow(Yast::NetworkInterfaces).to receive("GetValue").with("eth0", "NAME").and_return("Intel I217-LM")
    allow(Yast::NetworkInterfaces).to receive("GetValue").with("eth1", "NAME").and_return("Intel I217-LM")
  end

  describe "#interface_zone" do
    pending
    it "returns the zone name of the given interface" do
    end
  end

  describe "#known_interfaces" do
    pending
    it "returns a hash with the 'id', 'name' and zone of the current interfaces" do
    end
  end

  describe "#default_interfaces" do
    pending
    it "returns all the interface names that does not belong to any zone" do
    end
  end
end
