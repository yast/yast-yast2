# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yaml"
require_relative "../test_helper"

require "y2packager/product_reader"

describe Y2Packager::ProductReader do
  subject { Y2Packager::ProductReader.new }
  let(:products) { YAML.load(File.read(File.join(PACKAGES_FIXTURES_PATH, "products-sles15.yml"))) } # rubocop:disable Security/YAMLLoad
  let(:installation_package_map) { { "SLES" => "skelcd-SLES" } }

  describe "#available_base_products" do
    before do
      # TODO: proper mocking of pkg methods
      allow(subject).to receive(:installation_package_mapping).and_return(installation_package_map)
    end

    it "returns empty list if there is no product" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return([])
      expect(subject.available_base_products).to eq([])
    end

    it "returns Installation::Product objects" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return(products)
      expect(subject.available_base_products.first).to be_a(Y2Packager::Product)
    end

    it "returns the correct product properties" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return(products)
      ret = subject.available_base_products.first
      expect(ret.name).to eq("SLES")
      expect(ret.label).to eq("SUSE Linux Enterprise Server 15 Alpha1")
    end

    it "returns only the products from the initial repository" do
      sp3 = products.first
      addon1 = sp3.dup
      addon1["source"] = 1
      addon2 = sp3.dup
      addon2["source"] = 2

      expect(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return([addon2, addon1, sp3])

      expect(subject.available_base_products.size).to eq(1)
    end

    context "when no product with system-installation() tag exists" do
      let(:installation_package_map) { {} }
      let(:prod1) { { "name" => "SLES", "status" => :available } }
      let(:prod2) { { "name" => "SLED", "status" => :available } }

      before do
        allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
          .and_return(products)
      end

      context "and only 1 product exists" do
        let(:products) { [prod1] }

        it "returns the found product" do
          expect(subject.available_base_products.size).to eq(1)
        end
      end

      context "and more than 1 product exsits" do
        let(:products) { [prod1, prod2] }

        it "returns an empty array" do
          expect(subject.available_base_products).to be_empty
        end
      end
    end
  end

  describe "#installed_base_product" do
    let(:base_prod) do
      # reuse the available SLES15 product, just change some attributes
      base = products.first.dup
      base["name"] = "base_product"
      base["type"] = "base"
      base["status"] = :installed
      base
    end

    it "returns the installed base product" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return(products + [base_prod])
      expect(subject.installed_base_product.name).to eq("base_product")
    end
  end

  describe "#all_products" do
    let(:special_prod) do
      # reuse the available SLES15 product, just change some attributes
      special = products.first.dup
      special["name"] = "SLES_BCL"
      special["status"] = :available
      special["product_package"] = "SLES_BCL-release"
      special["display_name"] = "SUSE Linux Enterprise Server 15 Business Critical Linux"
      special["short_name"] = "SLE-15-BCL"
      special
    end

    before do
      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return(products + [special_prod])
      allow(Yast::Pkg).to receive(:PkgQueryProvides).with("system-installation()")
        .and_return([])
      allow(subject).to receive(:product_package).with("sles-release")
        .and_return(nil)
      allow(subject).to receive(:product_package).with("SLES_BCL-release")
        .and_return("deps" => [{ "conflicts"=>"kernel < 4.4" },
                               { "provides"=>"specialproduct(SLES_BCL)" }])
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return(nil)
    end

    it "returns available products without special products" do
      expect(subject.all_products.size).to eq(1)
    end

    it "returns available products with special product" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("SLES_BCL")
      expect(subject.all_products.size).to eq(2)
    end

    it "ignores case of the linuxrc specialproduct parameter" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("sles_bcl")
      expect(subject.all_products.size).to eq(2)
    end

    it "ignores underscores in the linuxrc specialproduct parameter" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("sles_b_c_l")
      expect(subject.all_products.size).to eq(2)
    end

    it "ignores underscores in the product name" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("SLESBCL")
      expect(subject.all_products.size).to eq(2)
    end

    it "ignores dashes in the linuxrc specialproduct parameter" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("sles-b-c-l")
      expect(subject.all_products.size).to eq(2)
    end

    it "ignores dots in the linuxrc specialproduct parameter" do
      allow(Yast::Linuxrc).to receive(:InstallInf).with("specialproduct").and_return("sles.b.c.l")
      expect(subject.all_products.size).to eq(2)
    end

    it "returns the available product also when an installed product is found" do
      installed = products.first.dup
      installed["status"] = :installed
      available = products.first.dup
      available["status"] = :available

      # return the installed product first to ensure the following available duplicate is not lost
      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return([installed, available])

      expect(subject.all_products).to_not be_empty
    end

    it "treats the selected and available products as duplicates even with different arch" do
      selected = products.first.dup
      selected["status"] = :selected
      available = products.first.dup
      available["status"] = :available
      available["arch"] = "i586"

      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "")
        .and_return([selected, available])

      expect(subject.all_products.size).to eq(1)
    end
  end
end
