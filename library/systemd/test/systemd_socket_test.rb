#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  import "SystemdSocket"

  describe SystemdSocket do
    subject(:systemd_socket) { SystemdSocketClass.new }

    include SystemdSocketStubs

    before do
      stub_sockets
    end

    describe ".find" do
      it "returns the unit object specified in parameter" do
        socket = SystemdSocket.find "iscsid"
        expect(socket).to be_a(SystemdUnit)
        expect(socket.unit_type).to eq("socket")
        expect(socket.unit_name).to eq("iscsid")
      end
    end

    describe ".find!" do
      it "returns the unit object specified in parameter" do
        socket = SystemdSocket.find "iscsid"
        expect(socket).to be_a(SystemdUnit)
        expect(socket.unit_type).to eq("socket")
        expect(socket.unit_name).to eq("iscsid")
      end

      it "raises SystemdSocketNotFound error if unit does not exist" do
        stub_sockets(socket: "unknown")
        expect { SystemdSocket.find!("unknown") }.to raise_error(SystemdSocketNotFound)
      end
    end

    describe ".all" do
      it "returns all supported sockets found" do
        sockets = SystemdSocket.all
        expect(sockets).to be_a(Array)
        expect(sockets).not_to be_empty
        sockets.each { |s| expect(s.unit_type).to eq("socket") }
      end

      describe ".for_service" do
        let(:finder) { instance_double(Yast2::SystemdSocketFinder, for_service: socket) }
        let(:socket) { instance_double(SystemdSocketClass::Socket) }

        before do
          allow(Yast2::SystemdSocketFinder).to receive(:new).and_return(finder)
        end

        it "returns the socket for the given service" do
          expect(subject.for_service("cups")).to eq(socket)
        end

        context "when there is not associated socket" do
          let(:socket) { nil }

          it "returns nil" do
            expect(subject.for_service("cups")).to be_nil
          end
        end
      end
    end

    describe "#listening?" do
      it "returns true if the socket is accepting connections" do
        socket = SystemdSocket.find "iscsid"
        expect(socket.listening?).to eq(true)
      end

      it "returns false if the socket is dead" do
        socket = SystemdSocket.find "iscsid"
        socket.properties.sub_state = "dead"
        expect(socket.listening?).to eq(false)
      end
    end
  end
end
