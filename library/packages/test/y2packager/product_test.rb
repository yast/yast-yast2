#!/usr/bin/env rspec

require_relative "../test_helper"

require "y2packager/product"

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
  let(:products) { [sles, sdk] }

  before do
    allow(Y2Packager::ProductReader).to receive(:new).and_return(reader)
    allow(reader).to receive(:all_products).and_return(products)
  end

  describe ".selected_base" do
    let(:not_selected) { instance_double(Y2Packager::Product, selected?: false) }
    let(:selected) { instance_double(Y2Packager::Product, selected?: true) }

    it "returns base selected packages" do
      allow(described_class).to receive(:available_base_products)
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
      allow(Yast::Pkg).to receive(:ResolvableProperties).with(product.name, :product, "")
        .and_return([{ "name" => product.name, "status" => status }])
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
      allow(Yast::Pkg).to receive(:ResolvableProperties).with(product.name, :product, "")
        .and_return([{ "name" => product.name, "status" => status }])
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

  describe "#license_content" do
    let(:license_content) { "license content" }
    let(:lang) { "en_US" }
    let(:license_reader) { product.send(:license_reader) }

    before do
      allow(Yast::Pkg).to receive(:PrdGetLicenseToConfirm).with(product.name, lang)
        .and_return(license_content)
      allow(license_reader).to receive(:license_content).and_return(license_content)
    end

    it "return the license content" do
      expect(product.license_content(lang)).to eq(license_content)
    end

    context "when the no license to confirm was found" do
      let(:license_content) { "" }

      it "return the empty string" do
        expect(product.license_content(lang)).to eq("")
      end
    end

    context "when the product does not exist" do
      let(:license_content) { nil }

      it "return nil" do
        expect(product.license_content(lang)).to be_nil
      end
    end
  end

  describe "#license?" do
    let(:lang) { "en_US" }
    let(:license) { instance_double("Y2Packager::License") }

    before do
      allow(product).to receive(:license).and_return(license)
    end

    context "when product has a license" do
      it "returns true" do
        expect(product.license?).to eq(true)
      end
    end

    context "when product does not have a license" do
      let(:license) { nil }

      it "returns false" do
        expect(product.license?).to eq(false)
      end
    end
  end

  describe "#license_locales" do
    it "returns license locales from libzypp" do
      expect(Yast::Pkg).to receive(:PrdLicenseLocales).with(product.name)
        .and_return(["en_US", "de_DE"])
      expect(product.license_locales).to eq(["en_US", "de_DE"])
    end

    context "when the empty locale is reported by libzypp" do
      before do
        allow(Yast::Pkg).to receive(:PrdLicenseLocales).with(product.name)
          .and_return([""])
      end

      it "converts it to the default one (en_US)" do
        expect(product.license_locales).to eq(["en_US"])
      end
    end

    context "when the product is not found" do
      before do
        allow(Yast::Pkg).to receive(:PrdLicenseLocales).and_return(nil)
      end

      it "returns an empty array" do
        expect(product.license_locales).to eq([])
      end
    end
  end

  describe "#license_confirmation_required?" do
    before do
      allow(Yast::Pkg).to receive(:PrdNeedToAcceptLicense).with(product.name).and_return(needed)
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
    context "when 'true' is given" do
      it "confirms the license" do
        expect(Yast::Pkg).to receive(:PrdMarkLicenseConfirmed).with(product.name)
        product.license_confirmation = true
      end
    end

    context "when 'false' is given" do
      it "sets as unconfirmed the license" do
        expect(Yast::Pkg).to receive(:PrdMarkLicenseNotConfirmed).with(product.name)
        product.license_confirmation = false
      end
    end
  end

  describe "#license_confirmed?" do
    before do
      allow(Yast::Pkg).to receive(:PrdHasLicenseConfirmed).with(product.name)
        .and_return(confirmed)
    end

    context "when the license has not been confirmed" do
      let(:confirmed) { false }

      it "returns false" do
        expect(product.license_confirmed?).to eq(false)
      end
    end

    context "when the license was already confirmed" do
      let(:confirmed) { true }

      it "returns true" do
        expect(product.license_confirmed?).to eq(true)
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
        { "name" => "openSUSE", "status" => :removed },
        { "name" => "openSUSE", "status" => :selected }
      ]
    end

    before do
      allow(Yast::Pkg).to receive(:ResolvableProperties)
        .with("openSUSE", :product, "").and_return(properties)
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
      allow(Yast::Pkg).to receive(:ResolvableProperties).with(product.name, :product, "")
        .and_return([{ "version" => product.version, "relnotes_url" => relnotes_url }])
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
        allow(Yast::Pkg).to receive(:ResolvableProperties).with(product.name, :product, "")
          .and_return([])
      end

      it "returns nil" do
        expect(product.relnotes_url).to be_nil
      end
    end
  end
end
