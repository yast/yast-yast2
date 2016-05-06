#!/usr/bin/env rspec

require_relative "test_helper"

require "packages/repository_product"

describe Packages::RepositoryProduct do
  subject(:product) do
    Packages::RepositoryProduct.new(name: "openSUSE", version: "20160405", arch: "x86_64",
      category: "addon", status: :available)
  end

  describe "==" do
    let(:other_data) do
      { name: "openSUSE", version: "20160405", arch: "x86_64",
        category: "addon", status: :installed }
    end

    context "when name and arch" do
      let(:other) { Packages::RepositoryProduct.new(other_data) }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when name does not match" do
      let(:other) { Packages::RepositoryProduct.new(other_data.merge(name: "other")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when version does not match" do
      let(:other) { Packages::RepositoryProduct.new(other_data.merge(version: "20160409")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when arch does not match" do
      let(:other) { Packages::RepositoryProduct.new(other_data.merge(arch: "i586")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end
end
