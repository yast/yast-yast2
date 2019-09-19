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

require "y2packager/product_control_product"

describe Y2Packager::ProductControlProduct do
  let(:product_data) do
    {
      "label"           => "SUSE Linux Enterprise Server 15 SP2",
      "name"            => "SLES",
      "version"         => "15.2",
      "register_target" => "sle-15-$arch"
    }
  end

  describe ".products" do
    before do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("")
      allow(Yast::ProductFeatures).to receive(:GetFeature)
        .with("software", "base_products").and_return([])
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    end

    after do
      # the read products are cached, we need to reset them manually for the next test
      described_class.instance_variable_set(:@products, nil)
    end

    it "reads the products from the control.xml" do
      expect(Yast::ProductFeatures).to receive(:GetFeature)
        .with("software", "base_products").and_return([product_data])

      products = Y2Packager::ProductControlProduct.products
      expect(products).to_not be_empty
      expect(products.first).to be_a(Y2Packager::ProductControlProduct)
      expect(products.first.name).to eq("SLES")
    end

    it "ignores the hidden products" do
      data = product_data.merge("special_product" => true)
      expect(Yast::ProductFeatures).to receive(:GetFeature)
        .with("software", "base_products").and_return([data])

      products = Y2Packager::ProductControlProduct.products
      expect(products).to be_empty
    end

    it "ignores the products for incompatible archs" do
      data = product_data.merge("archs" => "aarch64")
      expect(Yast::ProductFeatures).to receive(:GetFeature)
        .with("software", "base_products").and_return([data])

      products = Y2Packager::ProductControlProduct.products
      expect(products).to be_empty
    end

    it "expands the $arch variable in the register_target value" do
      expect(Yast::ProductFeatures).to receive(:GetFeature)
        .with("software", "base_products").and_return([product_data])

      product = Y2Packager::ProductControlProduct.products.first
      expect(product.register_target).to eq("sle-15-x86_64")
    end
  end

  describe ".selected" do
    after do
      # ensure the selected product is reset after each test
      described_class.instance_variable_set(:@selected, nil)
    end

    it "returns nil by default" do
      expect(described_class.selected).to be_nil
    end

    it "returns the selected product" do
      product = described_class.new(name: "SLES", version: "15.2", arch: "x86_64",
        label: "SUSE Linux Enterprise Server 15 SP2", license_url: "", register_target: "")
      described_class.selected = product
      expect(described_class.selected).to be(product)
    end
  end
end
