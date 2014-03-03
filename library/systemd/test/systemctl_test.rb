#!/usr/bin/env rspec

require_relative 'test_helper'
require 'yast2/systemctl'

module Yast
  describe Systemctl do
    include SystemctlStubs

    describe ".socket_units" do
      before { stub_systemctl(:socket) }
      it "returns a list of socket unit ids registered with systemd" do
        socket_units = Systemctl.socket_units
        expect(socket_units).to be_a(Array)
        expect(socket_units).not_to be_empty
        socket_units.each {|u| expect(u).to match(/.socket$/) }
      end
    end

    describe ".service_units" do
      before { stub_systemctl(:service) }
      it "returns a list of service units" do
        service_units = Systemctl.service_units
        expect(service_units).to be_a(Array)
        expect(service_units).not_to be_empty
        service_units.each {|u| expect(u).to match(/.service$/)/ }
      end
    end
  end
end
