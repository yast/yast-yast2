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
  subject(:product_license) do
    Y2Packager::ProductLicense.new(product_name, license)
  end

  let(:product_name) { "SLES" }
  let(:handler) { instance_double(Y2Packager::LicensesHandlers::Libzypp, :confirmation= => nil) }
  let(:license) do
    instance_double(Y2Packager::License, accept!: true, reject!: false, handler: handler)
  end

  before do
    described_class.clear_cache
  end

  describe ".find" do
    before do
      allow(Y2Packager::License).to receive(:find).and_return(license)
    end

    it "returns a product license for the given product" do
      expect(Y2Packager::License).to receive(:find).with("SLES", content: nil)
        .and_return(license)
      product_license = described_class.find("SLES")
      expect(product_license).to be_a(Y2Packager::ProductLicense)
      expect(product_license.license).to eq(license)
    end

    context "when the product license was already found" do
      it "returns the already found instance" do
        cached_product_license = described_class.find("SLES")
        product_license = described_class.find("SLES")
        expect(product_license).to be(cached_product_license)
      end
    end

    context "when a suitable license is not found" do
      before do
        allow(Y2Packager::License).to receive(:find).and_return(nil)
      end

      it "returns nil" do
        expect(described_class.find("SLES")).to be_nil
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
    subject(:product_license) do
      Y2Packager::ProductLicense.new(product_name, license)
    end

    let(:license) { Y2Packager::License.new(content: "Some content") }

    before do
      allow(license).to receive(:handler).and_return(handler)
    end

    it "delegates to License#accept!" do
      expect(license).to receive(:accept!).and_call_original
      product_license.accept!
    end

    context "when a handler for the handler is given" do
      it "synchronizes the handler" do
        expect(handler).to receive(:confirmation=).with(true)
        product_license.accept!
      end
    end

    context "when a handler was not given" do
      let(:handler) { nil }

      it "does not try to synchronize the status and does not crash" do
        expect(license).to receive(:accept!).and_call_original
        product_license.accept!
      end
    end
  end

  describe "#reject!" do
    subject(:product_license) do
      Y2Packager::ProductLicense.new(product_name, license)
    end

    let(:license) { Y2Packager::License.new(content: "Some content") }

    before do
      allow(license).to receive(:handler).and_return(handler)
    end

    it "delegates to License#reject!" do
      expect(license).to receive(:reject!)
      product_license.reject!
    end

    context "when a handler for the handler is given" do
      it "synchronizes the handler" do
        expect(handler).to receive(:confirmation=).with(false)
        product_license.reject!
      end
    end

    context "when a handler was not given" do
      let(:handler) { nil }

      it "does not try to synchronize the status and does not crash" do
        expect(license).to receive(:reject!).and_call_original
        product_license.reject!
      end
    end
  end

  describe "#accepted?" do
    before do
      allow(license).to receive(:accepted?).and_return(accepted?)
    end

    context "if the product license has been accepted" do
      let(:accepted?) { true }

      it "returns true" do
        expect(product_license).to be_accepted
      end

      it "synchronizes the handler" do
        expect(handler).to receive(:confirmation=).with(true)
        product_license.reject!
      end
    end

    context "if the product license has not been accepted" do
      let(:accepted?) { false }

      it "returns false" do
        expect(product_license).to_not be_accepted
      end

      it "synchronizes the handler" do
        expect(handler).to receive(:confirmation=).with(false)
        product_license.reject!
      end
    end

    context "when a handler was not given" do
      let(:handler) { nil }
      let(:accepted?) { true }

      it "does not try to synchronize the status and does not crash" do
        product_license.accepted?
      end
    end
  end
end
