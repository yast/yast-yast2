#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PortAliases"

FILE_CONTENT = <<EOS.freeze
blocks             10288/tcp    # Blocks  [Carl_Malamud]
blocks             10288/udp    # Blocks  [Carl_Malamud]
cosir              10321/tcp    # Computer Op System Information Report  [Kevin_C_Barber]
#                  10321/udp    Reserved
bngsync            10439/udp    # BalanceNG session table synchronization protocol  [Inlab_Software_GmbH] [Thomas_G._Obermair]
#                  10439/tcp    Reserved
#                  10500/tcp    Reserved
hip-nat-t          10500/udp    # HIP NAT-Traversal  [RFC5770] [Ari_Keranen]
MOS-lower          10540/tcp    # MOS Media Object Metadata Port  [Eric_Thorniley]
MOS-lower          10540/udp    # MOS Media Object Metadata Port  [Eric_Thorniley]
MOS-upper          10541/tcp    # MOS Running Order Port  [Eric_Thorniley]
MOS-upper          10541/udp    # MOS Running Order Port  [Eric_Thorniley]
EOS

describe Yast::PortAliases do
  describe ".LoadAndReturnNameToPort" do
    before do
      allow(::File).to receive(:read).and_return(FILE_CONTENT)
    end

    it "returns integer for given port name" do
      expect(Yast::PortAliases.LoadAndReturnNameToPort("blocks")).to eq 10288
    end

    it "returns nil if given port name not found" do
      expect(Yast::PortAliases.LoadAndReturnNameToPort("hellrouting")).to eq nil
    end

    it "does not interpret regexp characters" do
      expect(Yast::PortAliases.LoadAndReturnNameToPort("b.*s")).to eq nil
    end

    it "respects SCR chroot" do
      allow(Yast::WFM).to receive(:scr_root).and_return("/mnt")
      expect(::File).to receive(:read).with("/mnt/etc/services").and_return(FILE_CONTENT)

      Yast::PortAliases.LoadAndReturnNameToPort("test")
    end

    it "returns nil in case of IO Error" do
      allow(::File).to receive(:read).and_raise(IOError)

      expect(Yast::PortAliases.LoadAndReturnNameToPort("b.*s")).to eq nil
    end
  end
end
