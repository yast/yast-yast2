#!/usr/bin/env rspec

require_relative "../test_helper"

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
        allow(Yast::Pkg).to receive(:ResolvableProperties).and_return([])
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
  end

  describe ".will_be_obsolated_by" do
    context "given product is not installed" do
      it "returns an empty array" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, hpc_module])
        expect(described_class.will_be_obsolated_by("not_there")).to be_empty
      end
    end

    context "given product is installed but not required module" do
      it "returns an empty array" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, sles_hpc])
        expect(described_class.will_be_obsolated_by("SLES")).to be_empty
      end
    end

    context "given product and the required module is installed" do
      it "returns the product which obsoletes the old one" do
        expect(Y2Packager::Product).to receive(:installed_products)
          .and_return([sles, hpc_module])
        expect(described_class.will_be_obsolated_by("SLES")).to contain_exactly("SLE_HPC")
      end
    end
  end
end
