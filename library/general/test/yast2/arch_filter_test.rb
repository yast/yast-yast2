#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "yast2/arch_filter"

describe Yast2::ArchFilter do
  describe "#match?" do
    context "at least one positive methods return true" do
      context "all negative methods return false" do
        it "returns true" do
          filter = described_class.from_string("x86_64,ppc,!board_powernv")
          allow(Yast::Arch).to receive(:x86_64).and_return(false)
          allow(Yast::Arch).to receive(:ppc).and_return(true)
          allow(Yast::Arch).to receive(:board_powernv).and_return(false)

          expect(filter.match?).to eq true
        end
      end

      context "there are no negative methods" do
        it "returns true" do
          filter = described_class.from_string("x86_64,board_powernv")
          allow(Yast::Arch).to receive(:x86_64).and_return(false)
          allow(Yast::Arch).to receive(:board_powernv).and_return(true)

          expect(filter.match?).to eq true
        end
      end

      context "at least one negative method returns true" do
        it "returns false" do
          filter = described_class.from_string("x86_64,ppc,!board_powernv")
          allow(Yast::Arch).to receive(:x86_64).and_return(false)
          allow(Yast::Arch).to receive(:ppc).and_return(true)
          allow(Yast::Arch).to receive(:board_powernv).and_return(true)

          expect(filter.match?).to eq false
        end
      end
    end

    context "all positive methods return false" do
      it "returns false" do
        filter = described_class.from_string("x86_64,ppc,!board_powernv")
        allow(Yast::Arch).to receive(:x86_64).and_return(false)
        allow(Yast::Arch).to receive(:ppc).and_return(false)
        allow(Yast::Arch).to receive(:board_powernv).and_return(false)

        expect(filter.match?).to eq false
      end
    end

    context "there are no positive methods" do
      it "returns false" do
        filter = described_class.from_string("!x86_64,!board_powernv")
        allow(Yast::Arch).to receive(:x86_64).and_return(false)
        allow(Yast::Arch).to receive(:board_powernv).and_return(false)

        expect(filter.match?).to eq false
      end
    end

    context "there are no methods" do
      it "returns false" do
        filter = described_class.from_string("")

        expect(filter.match?).to eq false
      end
    end

    it "supports special 'all' method" do
        filter = described_class.from_string("all,!x86_64")
        allow(Yast::Arch).to receive(:x86_64).and_return(false)

        expect(filter.match?).to eq true
    end
  end

  describe ".new" do
    it "parses each element of list to specification" do
      filter = described_class.new(["x86_64"])
      expect(filter.specifications).to eq([{ method: :x86_64, negate: false }])
    end

    it "parses negative methods" do
      filter = described_class.new(["!x86_64"])
      expect(filter.specifications).to eq([{ method: :x86_64, negate: true }])
    end

    it "is case insensitive" do
      filter = described_class.new(["PPC"])
      expect(filter.specifications).to eq([{ method: :ppc, negate: false }])
    end

    it "raises Yast2::ArchFilter::Invalid for invalid methods" do
      expect { described_class.new(["InvalidArch"]) }.to raise_error(Yast2::ArchFilter::Invalid)
    end
  end

  describe ".from_string" do
    it "parses string into list of specifications" do
      filter = described_class.from_string("x86_64")
      expect(filter.specifications).to eq([{ method: :x86_64, negate: false }])
    end

    it "parses list separated by comma" do
      filter = described_class.from_string("x86_64,ppc")
      expect(filter.specifications).to eq(
        [
          { method: :x86_64, negate: false },
          { method: :ppc, negate: false }
        ]
      )
    end

    it "allows whitespaces" do
      filter = described_class.from_string("x86_64, ppc")
      expect(filter.specifications).to eq(
        [
          { method: :x86_64, negate: false },
          { method: :ppc, negate: false }
        ]
      )
    end
  end
end
