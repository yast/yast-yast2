#!/usr/bin/env rspec

require_relative 'test_helper'
require 'yast2/systemctl'

module Yast
  describe Systemctl do
    include SystemctlStubs

    before do
      stub_systemctl
    end

    describe ".socket_units" do
      it "returns a list of socket unit ids registered with systemd" do
        socket_units = Systemctl.socket_units
        expect(socket_units).to be_a(Array)
        expect(socket_units).not_to be_empty
        socket_units.each {|u| expect(u).to match(/.socket$/) }
      end
    end
  end
end
