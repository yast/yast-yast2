#!/usr/bin/env rspec

require_relative "../test_helper"

require "y2packager/product"
Yast.import "ProductFeatures"

describe Y2Packager::Product do
  PRODUCT_BASE_ATTRS = {
    name: "openSUSE", version: "20160405", arch: "x86_64",
    category: "addon", vendor: "openSUSE"
  }.freeze

  subject(:product) do
    Y2Packager::Product.new(PRODUCT_BASE_ATTRS)
  end

  let(:reader) { Y2Packager::ProductReader.new }
  let(:sles) { instance_double(Y2Packager::Product) }
  let(:sdk) { instance_double(Y2Packager::Product) }
  let(:product_license) { instance_double(Y2Packager::ProductLicense, content_for: "content") }
  let(:products) { [sles, sdk] }

  before do
    allow(Y2Packager::ProductReader).to receive(:new).and_return(reader)
    allow(reader).to receive(:all_products).and_return(products)
    allow(product).to receive(:license).and_return(product_license)
  end

  describe ".selected_base" do
    let(:not_selected) { instance_double(Y2Packager::Product, selected?: false) }
    let(:selected) { instance_double(Y2Packager::Product, selected?: true) }

    it "returns base selected packages" do
      allow(reader).to receive(:available_base_products)
        .and_return([not_selected, selected])

      expect(described_class.selected_base).to eq(selected)
    end
  end

  describe ".all" do
    it "returns all known products" do
      expect(described_class.all).to eq(products)
    end
  end

  describe ".with_status" do
    before do
      allow(sles).to receive(:status?).with(:installed).and_return(true)
      allow(sdk).to receive(:status?).with(:installed).and_return(false)
    end

    it "filters package with the given status" do
      expect(described_class.with_status(:installed))
        .to eq([sles])
    end
  end

  describe ".forced_base_product" do
    let(:select_product) { nil }

    let(:opensuse) do
      instance_double(Y2Packager::Product, name: "openSUSE", installation_package: true)
    end

    let(:sle) do
      instance_double(Y2Packager::Product, name: "SLE", installation_package: true)
    end

    before do
      described_class.reset

      allow(described_class).to receive(:available_base_products)
        .and_return([opensuse, sle])

      allow(Yast::ProductFeatures).to receive(:GetStringFeature)
        .with("software", "select_product")
        .and_return(select_product)
    end

    context "when the control file is not forcing to select a base product selected" do
      it "returns nil" do
        expect(described_class.forced_base_product).to be_nil
      end
    end

    context "when the control file is not forcing to select a base product selected" do
      context "and the product is available" do
        let(:select_product) { "openSUSE" }

        it "returns the prodcut" do
          expect(described_class.forced_base_product).to eq(opensuse)
        end
      end

      context "but none available base product name match" do
        let(:select_product) { "Whatever product" }

        it "returns nil" do
          expect(described_class.forced_base_product).to be_nil
        end
      end

      context "but is empty" do
        let(:select_product) { "" }

        it "returns nil" do
          expect(described_class.forced_base_product).to be_nil
        end
      end
    end

    let(:not_selected) { instance_double(Y2Packager::Product, selected?: false) }
    let(:selected) { instance_double(Y2Packager::Product, selected?: true) }

    it "returns base selected packages" do
      allow(reader).to receive(:available_base_products)
        .and_return([not_selected, selected])

      expect(described_class.selected_base).to eq(selected)
    end
  end

  describe "#==" do
    context "when name, arch, version and vendor match" do
      let(:other) { Y2Packager::Product.new(PRODUCT_BASE_ATTRS) }

      it "returns true" do
        expect(subject == other).to eq(true)
      end
    end

    context "when name does not match" do
      let(:other) { Y2Packager::Product.new(PRODUCT_BASE_ATTRS.merge(name: "other")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when version does not match" do
      let(:other) { Y2Packager::Product.new(PRODUCT_BASE_ATTRS.merge(version: "20160409")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when arch does not match" do
      let(:other) { Y2Packager::Product.new(PRODUCT_BASE_ATTRS.merge(arch: "i586")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end

    context "when vendor does not match" do
      let(:other) { Y2Packager::Product.new(PRODUCT_BASE_ATTRS.merge(vendor: "SUSE")) }

      it "returns false" do
        expect(subject == other).to eq(false)
      end
    end
  end

  describe "#selected?" do
    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(name: product.name, kind: :product)
        .and_return([Y2Packager::Resolvable.new("kind" => :product,
        "name" => product.name, "status" => status,
        "source" => 1, "short_name" => "short_name",
        "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
        "display_name" => "display_name", "category" => "addon",
        "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany")])
    end

    context "if product was selected for installation" do
      let(:status) { :selected }

      it "returns true" do
        expect(product).to be_selected
      end
    end

    context "if product was not selected for installation" do
      let(:status) { :none }

      it "returns false" do
        expect(product).to_not be_selected
      end
    end
  end

  describe "#installed?" do
    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(name: product.name, kind: :product)
        .and_return([Y2Packager::Resolvable.new("kind" => :product,
        "name" => product.name, "status" => status,
        "source" => 1, "short_name" => "short_name",
        "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
        "display_name" => "display_name", "category" => "addon",
        "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany")])
    end

    context "if product is installed" do
      let(:status) { :installed }

      it "returns true" do
        expect(product).to be_installed
      end
    end

    context "if product is not installed" do
      let(:status) { :available }

      it "returns false" do
        expect(product).to_not be_installed
      end
    end
  end

  describe "#select" do
    it "selects the product for installation" do
      expect(Yast::Pkg).to receive(:ResolvableInstall).with(product.name, :product, "")
      product.select
    end
  end

  describe "#restore" do
    it "restores product status" do
      expect(Yast::Pkg).to receive(:ResolvableNeutral).with(product.name, :product, true)
      product.restore
    end
  end

  describe "#label" do
    context "when 'display_name' is present" do
      subject(:product) do
        Y2Packager::Product.new(name: "NAME", display_name: "DISPLAY", short_name: "SHORT")
      end

      it "returns 'display_name'" do
        expect(product.label).to eq("DISPLAY")
      end
    end

    context "when 'display_name' is not present" do
      subject(:product) { Y2Packager::Product.new(name: "NAME", short_name: "SHORT") }

      it "returns 'short_name'" do
        expect(product.label).to eq("SHORT")
      end
    end

    context "when 'display_name' nor 'short_name' are present" do
      subject(:product) { Y2Packager::Product.new(name: "NAME") }

      it "returns 'name'" do
        expect(product.label).to eq("NAME")
      end
    end
  end

  describe "#license" do
    before do
      allow(product).to receive(:license).and_call_original
    end

    it "returns the product license" do
      expect(Y2Packager::ProductLicense).to receive(:find).with(product.name)
        .and_return(product_license)
      expect(product.license).to be(product_license)
    end
  end

  describe "#license_content" do
    let(:lang) { "en_US" }

    it "returns the license content" do
      expect(product_license).to receive(:content_for).with(lang).and_return("content")
      expect(product.license_content(lang)).to eq("content")
    end

    context "when no license was found" do
      let(:product_license) { nil }

      it "returns the empty string" do
        expect(product.license_content(lang)).to eq("")
      end
    end
  end

  describe "#license?" do
    context "when the product has a license" do
      let(:product_license) { instance_double(Y2Packager::ProductLicense) }

      it "returns true" do
        expect(product.license?).to eq(true)
      end
    end

    context "when the product does not have a license" do
      let(:product_license) { nil }

      it "returns false" do
        expect(product.license?).to eq(false)
      end
    end
  end

  describe "#license_locales" do
    let(:product_license) do
      instance_double(Y2Packager::ProductLicense, locales: ["en_US", "de_DE"])
    end

    it "returns product license locales" do
      expect(product.license_locales).to eq(product_license.locales)
    end
  end

  describe "#license_confirmation_required?" do
    before do
      allow(product_license).to receive(:confirmation_required?).and_return(needed)
    end

    context "when accepting the license is required" do
      let(:needed) { true }

      it "returns true" do
        expect(product.license_confirmation_required?).to eq(true)
      end
    end

    context "when accepting the license is not required" do
      let(:needed) { false }

      it "returns false" do
        expect(product.license_confirmation_required?).to eq(false)
      end
    end
  end

  describe "#license_confirmation=" do
    let(:license) { instance_double(Y2Packager::ProductLicense, accept!: true, reject!: true) }

    before do
      allow(product).to receive(:license).and_return(license)
    end

    context "when 'true' is given" do
      it "confirms the license" do
        expect(license).to receive(:accept!)
        product.license_confirmation = true
      end
    end

    context "when 'false' is given" do
      it "sets as unconfirmed the license" do
        expect(license).to receive(:reject!)
        product.license_confirmation = false
      end
    end
  end

  describe "#license_confirmed?" do
    let(:license) { instance_double(Y2Packager::License, accepted?: confirmed) }
    let(:confirmed) { false }
    let(:license_confirmation_required) { true }

    before do
      allow(product).to receive(:license).and_return(license)
      allow(product).to receive(:license_confirmation_required?)
        .and_return(license_confirmation_required)
    end

    context "when the acceptance of the license is not required" do
      let(:license_confirmation_required) { false }

      it "returns true" do
        expect(product.license_confirmed?).to eq(true)
      end
    end

    context "when the acceptance of the license is required" do
      let(:license_confirmation_required) { true }

      context "and the license has not been confirmed" do
        it "returns false" do
          expect(product.license_confirmed?).to eq(false)
        end
      end

      context "and the license was already confirmed" do
        let(:confirmed) { true }

        it "returns true" do
          expect(product.license_confirmed?).to eq(true)
        end
      end
    end
  end

  describe "#release_notes" do
    let(:relnotes_reader) { Y2Packager::ReleaseNotesReader.new(product) }
    let(:lang) { "en_US" }
    let(:relnotes_content) { "Release Notes" }

    before do
      allow(Y2Packager::ReleaseNotesReader).to receive(:new)
        .and_return(relnotes_reader)
    end

    it "returns release notes in the given language using text format" do
      expect(relnotes_reader).to receive(:release_notes)
        .with(user_lang: lang, format: :txt)
        .and_return(relnotes_content)
      expect(product.release_notes(lang)).to eq(relnotes_content)
    end

    context "when format is given" do
      it "returns release notes in the given language/format" do
        expect(relnotes_reader).to receive(:release_notes)
          .with(user_lang: "de_DE", format: :rtf)
          .and_return(relnotes_content)
        expect(product.release_notes("de_DE", :rtf)).to eq(relnotes_content)
      end
    end
  end

  describe "#status?" do
    let(:properties) do
      [
        Y2Packager::Resolvable.new("kind" => :product,
          "name" => "openSUSE", "status" => :removed,
          "source" => 1, "short_name" => "short_name",
          "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
          "display_name" => "display_name", "category" => "addon",
          "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany"),
        Y2Packager::Resolvable.new("kind" => :product,
          "name" => "openSUSE", "status" => :selected,
          "source" => 1, "short_name" => "short_name",
          "version" => "1.0", "arch" => "x86_64", "product_package" => "testpackage",
          "display_name" => "display_name", "category" => "addon",
          "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany")
      ]
    end

    before do
      allow(Y2Packager::Resolvable).to receive(:find)
        .with(name: "openSUSE", kind: :product).and_return(properties)
    end

    context "when given status is within product statuses" do
      it "returns true" do
        expect(product.status?(:installed, :selected)).to eq(true)
      end
    end

    context "when given status is not within product statuses" do
      it "returns false" do
        expect(product.status?(:installed)).to eq(false)
      end
    end
  end

  describe "#relnotes_url" do
    let(:relnotes_url) { "http://doc.opensuse.org/openSUSE/release-notes-openSUSE.rpm" }

    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(name: product.name,
        kind: :product, version: product.version)
        .and_return([Y2Packager::Resolvable.new("kind" => :product,
        "name" => "openSUSE", "status" => :selected,
        "source" => 1, "short_name" => "short_name",
        "version" => product.version, "relnotes_url" => relnotes_url,
        "arch" => "x86_64", "product_package" => "testpackage",
        "display_name" => "display_name", "category" => "addon",
        "vendor" => "SUSE LINUX Products GmbH, Nuernberg, Germany")])
    end

    it "returns relnotes_url property" do
      expect(product.relnotes_url).to eq(relnotes_url)
    end

    context "when relnotes_url property is empty" do
      let(:relnotes_url) { "" }

      it "returns nil" do
        expect(product.relnotes_url).to be_nil
      end
    end

    context "when product properties are not found" do
      before do
        allow(Y2Packager::Resolvable).to receive(:find).with(name: product.name,
          kind: :product, version: product.version).and_return([])
      end

      it "returns nil" do
        expect(product.relnotes_url).to be_nil
      end
    end
  end
end
