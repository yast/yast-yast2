#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) [2018] SUSE LLC
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

require_relative "./test_helper"
Yast.import "Punycode"

describe Yast::Punycode do
  subject(:punycode) { Yast::Punycode }

  IP = "192.168.122.1".freeze
  NUMBER = "15".freeze

  before do
    punycode.main # reset the cache
  end

  describe "#ConvertBackAndForth" do
    context "when converting to Punycode" do
      it "returns all strings converted to Punycode" do
        expect(punycode.ConvertBackAndForth(["españa"], true)).to eq(["xn--espaa-rta"])
      end

      it "caches converted values" do
        expect(punycode).to receive(:CreateNewCacheRecord).with("españa", "xn--espaa-rta")
        punycode.ConvertBackAndForth(["españa"], true)
      end

      context "when the string is cached" do
        before do
          allow(subject).to receive(:GetEncodedCachedString).with("españa")
            .and_return("cached_value")
        end

        it "returns the cached value" do
          expect(punycode.ConvertBackAndForth(["españa"], true)).to eq(["cached_value"])
        end
      end
    end

    context "when converting to UTF-8" do
      it "returns all strings converted to UTF-8" do
        expect(punycode.ConvertBackAndForth(["xn--espaa-rta"], false)).to eq(["españa"])
      end

      it "caches converted values" do
        expect(punycode).to receive(:CreateNewCacheRecord).with("españa", "xn--espaa-rta")
        punycode.ConvertBackAndForth(["xn--espaa-rta"], false)
      end

      context "when the string is cached" do
        before do
          allow(subject).to receive(:GetDecodedCachedString).with("xn--espaa-rta")
            .and_return("cached_value")
        end

        it "returns the cached value" do
          expect(punycode.ConvertBackAndForth(["xn--espaa-rta"], false)).to eq(["cached_value"])
        end
      end
    end

    context "when an IP address is given" do
      it "is not converted" do
        expect(punycode.ConvertBackAndForth([IP], true)).to eq([IP])
      end
    end

    context "when a string representing a number is given" do
      it "is not converted" do
        expect(punycode.ConvertBackAndForth([NUMBER], true)).to eq([NUMBER])
      end
    end

    context "when an empty string is given" do
      it "is not converted" do
        expect(punycode.ConvertBackAndForth([""], true)).to eq([""])
      end
    end
  end

  describe "#EncodePunycodes" do
    it "returns strings converted to punycode ignoring numbers, IP addresses and empty strings" do
      punycodes = punycode.EncodePunycodes(["españa", NUMBER, IP, ""])
      expect(punycodes).to eq(["xn--espaa-rta", NUMBER, IP, ""])
    end
  end

  describe "#DecodePunycodes" do
    it "returns strings converted to unicode ignoring numbers, IP addresses and empty strings" do
      punycodes = punycode.DecodePunycodes(["xn--espaa-rta", NUMBER, IP, ""])
      expect(punycodes).to eq(["españa", NUMBER, IP, ""])
    end
  end
end
