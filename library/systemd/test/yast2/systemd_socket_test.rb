#!/usr/bin/env rspec

require_relative "../test_helper"

module Yast2
  describe Systemd::Socket do
    include SystemdSocketStubs

    before do
      stub_sockets
    end

    describe ".find" do
      it "returns the unit object specified in parameter" do
        socket = Systemd::Socket.find "iscsid"
        expect(socket).to be_a(Systemd::Unit)
        expect(socket.unit_type).to eq("socket")
        expect(socket.unit_name).to eq("iscsid")
      end
    end

    describe ".find!" do
      it "returns the unit object specified in parameter" do
        socket = Systemd::Socket.find "iscsid"
        expect(socket).to be_a(Systemd::Unit)
        expect(socket.unit_type).to eq("socket")
        expect(socket.unit_name).to eq("iscsid")
      end

      it "raises Systemd::SocketNotFound error if unit does not exist" do
        stub_sockets(socket: "unknown")
        expect { Systemd::Socket.find!("unknown") }.to raise_error(Systemd::SocketNotFound)
      end
    end

    describe ".all" do
      it "returns all supported sockets found" do
        sockets = Systemd::Socket.all
        expect(sockets).to be_a(Array)
        expect(sockets).not_to be_empty
        sockets.each { |s| expect(s.unit_type).to eq("socket") }
      end
    end

    describe "#listening?" do
      it "returns true if the socket is accepting connections" do
        socket = Systemd::Socket.find "iscsid"
        expect(socket.listening?).to eq(true)
      end

      it "returns false if the socket is dead" do
        socket = Systemd::Socket.find "iscsid"
        socket.properties.sub_state = "dead"
        expect(socket.listening?).to eq(false)
      end
    end
  end
end
