#!/usr/bin/env rspec

require_relative "../test_helper"

require "packages/product"

describe Packages::Product do
  BASE_ATTRS = {
    name: "openSUSE", version: "20160405", arch: "x86_64",
    category: "addon", status: :installed, vendor: "openSUSE"
  }.freeze

  subject(:product) do
    Packages::Product.new(BASE_ATTRS)
  end

  describe "==" do

    context "when name, arch, version and vendor match" do
      let(:other) { Packages::Product.new(BASE_ATTRS) }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when name does not match" do
      let(:other) { Packages::Product.new(BASE_ATTRS.merge(name: "other")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when version does not match" do
      let(:other) { Packages::Product.new(BASE_ATTRS.merge(version: "20160409")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when arch does not match" do
      let(:other) { Packages::Product.new(BASE_ATTRS.merge(arch: "i586")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when vendor does not match" do
      let(:other) { Packages::Product.new(BASE_ATTRS.merge(vendor: "SUSE")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end
end
