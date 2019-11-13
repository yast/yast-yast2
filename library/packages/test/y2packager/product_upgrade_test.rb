#!/usr/bin/env rspec

require_relative "../test_helper"

require "yaml"
require "y2packager/product_upgrade"
require "y2packager/product"

describe Y2Packager::ProductUpgrade do
  let(:product1) { Y2Packager::Product.new(name: "testing_product1") }
  let(:product2) { Y2Packager::Product.new(name: "testing_product2") }
  let(:product3) { Y2Packager::Product.new(name: "testing_product3") }
  let(:sles) { Y2Packager::Product.new(name: "SLES") }
  let(:sles_hpc) { Y2Packager::Product.new(name: "SLE_HPC") }
  let(:hpc_module) { Y2Packager::Product.new(name: "sle-module-hpc") }
  let(:sles11) { Y2Packager::Product.new(name: "SUSE_SLES") }
  let(:suma_proxy) { Y2Packager::Product.new(name: "SUSE-Manager-Proxy") }
  let(:suma_branch_server) { Y2Packager::Product.new(name: "SUSE-Manager-Retail-Branch-Server") }

  describe ".new_base_product" do
    context "no base product is available" do
      before do
        expect(Y2Packager::Product).to receive(:available_base_products).and_return([])
      end

      it "returns nil" do
        expect(described_class.new_base_product).to be_nil
      end
    end

    context "only one base product is available" do
      before do
        expect(Y2Packager::Product).to receive(:available_base_products).and_return([product1])
        allow(Y2Packager::Resolvable).to receive(:find).and_return([])
      end

      it "returns that product" do
        expect(described_class.new_base_product).to be(product1)
      end
    end

    context "several base products are available" do
      before do
        expect(Y2Packager::Product).to receive(:available_base_products)
          .and_return([product1, product2, sles, sles_hpc]).at_least(:once)
      end

      context "the new base product is found in the fallback mapping" do
        it "returns SLES for SLES11" do
          expect(Y2Packager::Product).to receive(:installed_products).and_return([sles11])
          expect(described_class.new_base_product).to be(sles)
        end

        it "returns SLE_HPC for SLES and HPC module installed" do
          expect(Y2Packager::Product).to receive(:installed_products)
            .and_return([sles, hpc_module])
          expect(described_class.new_base_product).to be(sles_hpc)
        end
      end

      context "the base product if found by name" do
        it "returns SLES for installed SLES" do
          expect(Y2Packager::Product).to receive(:installed_base_product)
            .and_return(sles)
          expect(described_class.new_base_product).to be(sles)
        end
      end

      it "returns nil if no upgrade product is found" do
        expect(Y2Packager::Product).to receive(:installed_base_product)
          .and_return(product3)
        expect(described_class.new_base_product).to be_nil
      end
    end

    context "SUSE Manager Retail Branch Server upgrade" do
      # there are "SLES + SUMA Proxy" and "SLES + SUMA Proxy + SUMA Branch Server"
      # mappings, make sure the longer one is preferred
      it "returns more matching installed products" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, suma_proxy, suma_branch_server])
        expect(Y2Packager::Product).to receive(:available_base_products)
          .and_return([sles, sles_hpc, suma_proxy, suma_branch_server])

        expect(described_class.new_base_product).to be(suma_branch_server)
      end
    end
  end

  describe ".will_be_obsoleted_by" do
    before do
      expect(Y2Packager::Product).to receive(:with_status).with(:selected)
        .and_return([Y2Packager::Product.new(name: "SLE_HPC")])
    end

    context "given product is not installed" do
      it "returns an empty array" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, hpc_module])
        expect(described_class.will_be_obsoleted_by("not_there")).to be_empty
      end
    end

    context "given product is installed but not required module" do
      it "returns an empty array" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, sles_hpc])
        expect(described_class.will_be_obsoleted_by("SLES")).to be_empty
      end
    end

    context "given product and the required module is installed" do
      it "returns the product which obsoletes the old one" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, hpc_module])
        expect(described_class.will_be_obsoleted_by("SLES")).to contain_exactly("SLE_HPC")
      end
    end
  end

  describe ".obsolete_upgrades" do
    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :product)
        .and_return(suma_products)
    end

    # upgrade from SLE12-SP3 + SUMA Proxy 3.2 + SUMA Branch Server 3.2
    # to SLE15-SP1 (actually to SUMA Branch Server 4.0)
    context "SUSE Manager Branch Retail Server 3.2 upgrade" do
      let(:suma_hash) { YAML.load_file(File.join(__dir__, "../data/zypp/products_update_suma_branch_server.yml")) }

      let(:suma_products) do
        suma_hash.map { |p| Y2Packager::Resolvable.new(p) }
      end

      before do
        allow(Y2Packager::Resolvable).to receive(:find).with(name: "SLES", kind: :product)
          .and_return(suma_products.select { |p| p.name == "SLES" })
        allow(Y2Packager::Resolvable).to receive(:find).with(name: "SUSE-Manager-Proxy", kind: :product)
          .and_return(suma_products.select { |p| p.name == "SUSE-Manager-Proxy" })
      end

      it "returns obsoleted SLES + SUMA Proxy product" do
        allow(Y2Packager::Resolvable).to receive(:any?).with(name: "SUSE-Manager-Proxy",
          kind: :product, status: :removed, transact_by: :solver).and_return(true)
        allow(Y2Packager::Resolvable).to receive(:any?).with(name: "SLES",
          kind: :product, status: :removed, transact_by: :solver).and_return(true)

        expect(described_class.obsolete_upgrades).to contain_exactly("SLES", "SUSE-Manager-Proxy")
      end

      it "returns empty list if the old product is removed by user" do
        allow(Y2Packager::Resolvable).to receive(:any?).with(name: "SUSE-Manager-Proxy",
          kind: :product, status: :removed, transact_by: :solver).and_return(false)
        allow(Y2Packager::Resolvable).to receive(:any?).with(name: "SLES",
          kind: :product, status: :removed, transact_by: :solver).and_return(false)

        expect(described_class.obsolete_upgrades).to eq([])
      end
    end

    context "SUSE Manager Proxy 3.2 upgrade" do
      let(:suma_products) do
        suma_hash = YAML.load_file(File.join(__dir__, "../data/zypp/products_update_suma_proxy.yml"))
        suma_hash.map { |p| Y2Packager::Resolvable.new(p) }
      end

      it "returns empty list" do
        allow(Y2Packager::Resolvable).to receive(:find).with(name: "SUSE-Manager-Proxy", kind: :product)
          .and_return(suma_products.select { |p| p.name == "SUSE-Manager-Proxy" })
        allow(Y2Packager::Resolvable).to receive(:find).with(name: "SLES", kind: :product)
          .and_return(suma_products.select { |p| p.name == "SLES" })
        expect(described_class.obsolete_upgrades).to eq([])
      end
    end
  end

  describe ".remove_obsolete_upgrades" do
    it "marks the obsolete products for removal" do
      obsolete = ["SLES", "SUSE-Manager-Proxy"]

      expect(described_class).to receive(:obsolete_upgrades).and_return(obsolete)
      obsolete.each { |o| expect(Yast::Pkg).to receive(:ResolvableRemove).with(o, :product) }

      described_class.remove_obsolete_upgrades
    end
  end
end
