#!/usr/bin/env rspec
# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "../test_helper"

require "y2packager/product_license"

describe Y2Packager::ProductLicense do
  subject(:product_license) { Y2Packager::ProductLicense.new(product_name, license) }

  let(:license) { instance_double(Y2Packager::License) }
  let(:product_name) { "SLES" }

  before do
    described_class.clear_cache
  end

  describe ".find" do
    before do
      allow(Y2Packager::License).to receive(:find).and_return(license)
    end

    it "returns a product license for the given product" do
      expect(Y2Packager::License).to receive(:find).with("SLES", source: :rpm, content: nil)
        .and_return(license)
      product_license = described_class.find("SLES", source: :rpm)
      expect(product_license).to be_a(Y2Packager::ProductLicense)
      expect(product_license.license).to eq(license)
    end

    context "when the product license was already found" do
      it "returns the already found instance" do
        cached_product_license = described_class.find("SLES", source: :rpm)
        product_license = described_class.find("SLES", source: :rpm)
        expect(product_license).to be(cached_product_license)
      end
    end

    context "when a suitable license is not found" do
      before do
        allow(Y2Packager::License).to receive(:find).and_return(nil)
      end

      it "returns nil" do
        expect(described_class.find("SLES", source: :rpm)).to be_nil
      end
    end

    context "when some content is given" do
      it "returns a product license with the given content" do
        expect(Y2Packager::License).to receive(:find).and_call_original
        product_license = described_class.find("SLES", content: "Some content")
        expect(product_license.content_for).to eq("Some content")
      end
    end
  end

  describe "#content_for" do
    it "delegates to License#content_for" do
      expect(license).to receive(:content_for).with("es_ES").and_return("contenido")
      expect(product_license.content_for("es_ES")).to eq("contenido")
    end
  end

  describe "#locales" do
    it "delegates to License#locales" do
      expect(license).to receive(:locales).and_return(["en_US", "de_DE"])
      expect(product_license.locales).to eq(["en_US", "de_DE"])
    end
  end

  describe "#accept!" do
    it "delegates to License#accept!" do
      expect(license).to receive(:accept!)
      product_license.accept!
    end
  end

  describe "#reject!" do
    it "delegates to License#reject!" do
      expect(license).to receive(:reject!)
      product_license.reject!
    end
  end

  describe "#accepted?" do
    context "if the product license has been accepted" do
      it "returns true"
    end

    context "if the product license has been accepted" do
      it "returns false"
    end

    context "synchronizes the license status"
  end
end
