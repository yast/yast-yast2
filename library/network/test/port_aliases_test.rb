#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PortAliases"

# FILE CONTENT example
#
# blocks             10288/tcp    # Blocks  [Carl_Malamud]
# blocks             10288/udp    # Blocks  [Carl_Malamud]
# cosir              10321/tcp    # Computer Op System Information Report  [Kevin_C_Barber]
# #                  10321/udp    Reserved
# bngsync            10439/udp    # BalanceNG session table synchronization protocol  [Inlab_Software_GmbH] [Thomas_G._Obermair]
# #                  10439/tcp    Reserved
# #                  10500/tcp    Reserved
# hip-nat-t          10500/udp    # HIP NAT-Traversal  [RFC5770] [Ari_Keranen]
# MOS-lower          10540/tcp    # MOS Media Object Metadata Port  [Eric_Thorniley]
# MOS-lower          10540/udp    # MOS Media Object Metadata Port  [Eric_Thorniley]
# MOS-upper          10541/tcp    # MOS Running Order Port  [Eric_Thorniley]
# MOS-upper          10541/udp    # MOS Running Order Port  [Eric_Thorniley]

GETENT_OUTPUT = <<~GETENT_OUTPUT.freeze
  blocks             10288
  blocks             10288
  cosir              10321
  bngsync            10439
  hip-nat-t          10500
  MOS-lower          10540
  MOS-lower          10540
  MOS-upper          10541
  MOS-upper          10541
GETENT_OUTPUT

describe Yast::PortAliases do
  let(:executor) { instance_double(Yast::Execute, on_target!: GETENT_OUTPUT) }

  before do
    allow(Yast::Execute).to receive(:stdout).and_return(executor)
  end

  describe ".IsAllowedPortName" do
    context "when nil is given" do
      it "logs an error" do
        expect(Yast::Builtins).to receive(:y2error).with(/Invalid/, nil)

        subject.IsAllowedPortName(nil)
      end

      it "returns false" do
        expect(subject.IsAllowedPortName(nil)).to eq(false)
      end
    end

    context "when a number is given" do
      context "within the valid port range" do
        it "returns true" do
          expect(subject.IsAllowedPortName("65535")).to eq(true)
        end
      end

      context "beyond the upper limit" do
        it "returns false" do
          expect(subject.IsAllowedPortName("65536")).to eq(false)
        end
      end
      context "below the lower limit" do
        # FIXME: regexp avoid having negative numbers, which are going to be considered as port name
        # instead a port number.
        xit "returns false" do
          expect(subject.IsAllowedPortName("-1")).to eq(false)
        end
      end
    end

    context "when a name is given" do
      context "containing only valid chars" do
        it "returns true" do
          expect(subject.IsAllowedPortName("valid-service.name+")).to eq(true)
        end
      end

      context "containing not valid chars" do
        it "returns false" do
          expect(subject.IsAllowedPortName("Not valid service name")).to eq(false)
        end
      end
    end
  end

  describe ".AllowedPortNameOrNumber" do
    it "returns an informing message" do
      message = subject.AllowedPortNameOrNumber

      expect(message).to include("a-z")
      expect(message).to include("A-Z")
      expect(message).to include("0-9")
      expect(message).to include("*+._-")
      expect(message).to include("0 to 65535")
    end
  end

  describe ".GetListOfServiceAliases" do
    context "when a port number is given" do
      context "and there is a service for such port number" do
        let(:port_number) { "10541" }

        it "returns a list holding both, the port number and its aliases" do
          expect(subject.GetListOfServiceAliases(port_number)).to eq(["10541", "MOS-upper"])
        end
      end

      context "but there is not a service for such port number" do
        let(:port_number) { "666" }

        it "returns a list holding only the given port number" do
          expect(subject.GetListOfServiceAliases(port_number)).to eq([port_number])
        end
      end
    end

    context "when a port name is given" do
      context "and its an allowed port name" do
        context "and there is a service for such port name" do
          let(:port_name) { "MOS-upper" }

          it "returns a list holding both, given name and its port number" do
            expect(subject.GetListOfServiceAliases(port_name)).to eq(["10541", "MOS-upper"])
          end
        end

        context "but there is not a service for such port number" do
          let(:port_name) { "SomethingWrong" }

          it "returns a list holding only the given name" do
            expect(subject.GetListOfServiceAliases(port_name)).to eq([port_name])
          end
        end

        context "but it is not an allowed port name" do
          let(:port_name) { "Something Not Allowed" }

          it "logs an error" do
            expect(Yast::Builtins).to receive(:y2error).with(/not allowed/, port_name)

            subject.GetListOfServiceAliases(port_name)
          end

          it "returns a list holding only the given name" do
            expect(subject.GetListOfServiceAliases(port_name)).to eq([port_name])
          end
        end
      end
    end
  end

  describe ".IsKnownPortName" do
    context "when a known port name is given" do
      let(:port_name) { "blocks" }

      it "returns true" do
        expect(subject.IsKnownPortName(port_name)).to eq(true)
      end
    end

    context "when an unknown port name is given" do
      let(:port_name) { "unknown-port" }

      it "returns false" do
        expect(subject.IsKnownPortName(port_name)).to eq(false)
      end
    end
  end

  describe ".GetPortNumber" do
    context "when a port number is given" do
      let(:port_number) { "80" }

      it "returns the Integer port number" do
        expect(subject.GetPortNumber(port_number)).to eq(80)
      end
    end

    context "when a port name is given" do
      context "and the port is known" do
        let(:port_name) { "MOS-lower" }

        it "returns its port number" do
          expect(subject.GetPortNumber(port_name)).to eq(10540)
        end
      end

      context "but the port is unknown" do
        let(:port_name) { "Unknown" }

        it "returns nil" do
          expect(subject.GetPortNumber(port_name)).to be_nil
        end
      end
    end
  end
end
