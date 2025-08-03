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
  let(:products_hash) { YAML.load_file(File.join(PACKAGES_FIXTURES_PATH, "products-sles15.yml")) }
  let(:products) do
    products_hash.map { |p| Y2Packager::Resolvable.new(p) }
  end

  let(:installation_package_map) { { "SLES" => "skelcd-SLES" } }

  describe "#available_base_products" do
    before do
      # TODO: proper mocking of pkg methods
      allow(subject).to receive(:installation_package_mapping).and_return(installation_package_map)
      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :package, name: //)
        .and_return([])
    end

    it "returns empty list if there is no product" do
      expect(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return([])
      expect(subject.available_base_products).to eq([])
    end

    it "returns Installation::Product objects" do
      expect(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return(products)
      expect(subject.available_base_products.first).to be_a(Y2Packager::Product)
    end

    it "returns the correct product properties" do
      expect(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return(products)
        .and_return(products)
      ret = subject.available_base_products.first
      expect(ret.name).to eq("SLES")
      expect(ret.label).to eq("SUSE Linux Enterprise Server 15 Alpha1")
    end

    it "returns only the products from the initial repository" do
      sp3_hash = products_hash.first
      addon1_hash = sp3_hash.dup
      addon1_hash["source"] = 1
      addon2_hash = sp3_hash.dup
      addon2_hash["source"] = 2
      sp3 = Y2Packager::Resolvable.new(sp3_hash)
      addon1 = Y2Packager::Resolvable.new(addon1_hash)
      addon2 = Y2Packager::Resolvable.new(addon2_hash)

      expect(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return([addon2, addon1, sp3])

      expect(subject.available_base_products.size).to eq(1)
    end

    context "when no product with system-installation() tag exists" do
      let(:installation_package_map) { {} }
      let(:prod1) do
        Y2Packager::Resolvable.new("kind" => :product,
          "name" => "SLES", "status" => :available, "source" => 1, "short_name" => "short_name",
          "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
          "display_name" => "display_name", "category" => "addon",
          "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany",
          "register_target" => "")
      end

      let(:prod2) do
        Y2Packager::Resolvable.new("kind" => :product,
          "name" => "SLED", "status" => :available, "source" => 2, "short_name" => "short_name",
          "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
          "display_name" => "display_name", "category" => "addon",
          "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany",
          "register_target" => "")
      end

      before do
        allow(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
          .and_return(products)
      end

      context "and only 1 product exists" do
        let(:products) { [prod1] }

        it "returns the found product" do
          expect(subject.available_base_products.size).to eq(1)
        end
      end

      context "and more than 1 product exists" do
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
      base = products_hash.first.dup
      base["name"] = "base_product"
      base["type"] = "base"
      base["status"] = :installed
      Y2Packager::Resolvable.new(base)
    end

    it "returns the installed base product" do
      expect(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return(products + [base_prod])
      expect(subject.installed_base_product.name).to eq("base_product")
    end
  end

  describe "#all_products" do
    let(:special_prod) do
      # reuse the available SLES15 product, just change some attributes
      special = products_hash.first.dup
      special["name"] = "SLES_BCL"
      special["status"] = :available
      special["product_package"] = "SLES_BCL-release"
      special["display_name"] = "SUSE Linux Enterprise Server 15 Business Critical Linux"
      special["short_name"] = "SLE-15-BCL"
      Y2Packager::Resolvable.new(special)
    end

    before do
      allow(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return(products + [special_prod])
      allow(Yast::Pkg).to receive(:PkgQueryProvides).with("system-installation()")
        .and_return([])
      allow(subject).to receive(:product_package).with("sles-release")
        .and_return(nil)
      allow(subject).to receive(:product_package).with("SLES_BCL-release")
        .and_return(Y2Packager::Resolvable.new("name" => "product_package",
          "source" => 1, "version" => "1.0", "arch" => "x86_64",
          "kind" => :package, "deps" => [{ "conflicts"=>"kernel < 4.4" },
                                         { "provides"=>"specialproduct(SLES_BCL)" }]))
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
      installed_hash = products_hash.first.dup
      installed_hash["status"] = :installed
      available_hash = products_hash.first.dup
      available_hash["status"] = :available
      available = Y2Packager::Resolvable.new(available_hash)
      installed = Y2Packager::Resolvable.new(installed_hash)

      # return the installed product first to ensure the following available duplicate is not lost
      allow(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return([installed, available])

      expect(subject.all_products).to_not be_empty
    end

    it "treats the selected and available products as duplicates even with different arch" do
      selected_hash = products_hash.first.dup
      selected_hash["status"] = :selected
      available_hash = products_hash.first.dup
      available_hash["status"] = :available
      available_hash["arch"] = "i586"
      selected = Y2Packager::Resolvable.new(selected_hash)
      available = Y2Packager::Resolvable.new(available_hash)

      allow(Y2Packager::Resolvable).to receive(:find).with({ kind: :product }, [:register_target])
        .and_return([selected, available])

      expect(subject.all_products.size).to eq(1)
    end
  end

  describe ".installation_package_mapping" do
    before do
      allow(Yast::Pkg).to receive(:PkgQueryProvides).with("system-installation()").and_return(
        # the first is the old product which will be removed from the system
        [["openSUSE-release", :CAND, :NONE], ["openSUSE-release", :CAND, :CAND]]
      )
      allow(Yast::Pkg).to receive(:Resolvables).with({ name: "openSUSE-release", kind: :package },
        [:dependencies, :status]).and_return(
          [
            {
              # emulate an older system with no "system-installation()" provides
              "deps"   => [],
              # put the removed product first so we can check it is skipped
              "status" => :removed
            },
            {
              # in reality there are many more dependencies, but they are irrelevant for this test
              "deps"   => [{ "provides" => "system-installation() = openSUSE" }],
              "status" => :selected
            }
          ]
        )
    end

    it "prefers the data from the new available product instead of the old installed one" do
      expect(described_class.installation_package_mapping).to eq("openSUSE" => "openSUSE-release")
    end
  end
end
