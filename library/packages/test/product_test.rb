#!/usr/bin/env rspec

require_relative "test_helper"

require "yaml"

# Important: Loads data in constructor
Yast.import "Product"

Yast.import "Mode"
Yast.import "Stage"
Yast.import "OSRelease"
Yast.import "PackageSystem"
Yast.import "Pkg"
Yast.import "PackageLock"
Yast.import "Mode"
Yast.import "Stage"

def load_zypp(file_name)
  file_name = File.join(PACKAGES_FIXTURES_PATH, "zypp", file_name)

  raise "File not found: #{file_name}" unless File.exist?(file_name)

  Yast.y2milestone "Loading file: #{file_name}"
  YAML.load_file(file_name)
end

def product_from_zypp
  load_zypp("products.yml").map { |p| Y2Packager::Resolvable.new(p) }
end

def stub_defaults
  Yast.y2milestone "--------- Running test ---------"
  Yast::Product.send(:reset)
  allow(Yast::PackageSystem).to receive(:EnsureTargetInit).and_return(true)
  allow(Yast::PackageSystem).to receive(:EnsureSourceInit).and_return(true)
  allow(Yast::Pkg).to receive(:PkgSolve).and_return(true)
  allow(Yast::PackageLock).to receive(:Check).and_return(true)
  allow(Y2Packager::Resolvable).to receive(:find).with(kind: :product).and_return(product_from_zypp)
end

# Describes Product handling as a whole (due to lazy loading and internal caching),
# methods descriptions are below
describe "Yast::Product (integration)" do
  before(:each) do
    stub_defaults
  end

  context "while called in installation system without os-release file" do
    before(:each) do
      allow(Yast::Stage).to receive(:stage).and_return("initial")
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(false)
    end

    describe "when the mode is Installation" do
      it "reads product information from zypp and fills up internal variables" do
        allow(Yast::Mode).to receive(:mode).and_return("installation")

        expect(Yast::Product.name).to eq("openSUSE (SELECTED)")
        expect(Yast::Product.short_name).to eq("openSUSE")
        expect(Yast::Product.version).to eq("13.1")
      end
    end

    describe "when the mode is Update" do
      it "reads product information from zypp and fills up internal variables" do
        allow(Yast::Mode).to receive(:mode).and_return("update")

        expect(Yast::Product.name).to eq("openSUSE (SELECTED)")
        expect(Yast::Product.short_name).to eq("openSUSE")
        expect(Yast::Product.version).to eq("13.1")
      end
    end
  end

  context "while called on a running system with os-release file" do
    before(:each) do
      allow(Yast::Stage).to receive(:stage).and_return("normal")
      allow(Yast::Mode).to receive(:mode).and_return("normal")
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(true)
    end

    # This is the default behavior
    context "OSRelease is complete" do
      it "reads product information from OSRelease and fills up internal variables" do
        release_info = "Happy Feet 2.0"

        allow(Yast::OSRelease).to receive(:ReleaseName).and_return("anything")
        allow(Yast::OSRelease).to receive(:ReleaseVersion).and_return("anything")
        allow(Yast::OSRelease).to receive(:ReleaseInformation).and_return(release_info)

        expect(Yast::Product.name).to eq(release_info)
      end
    end

    # This is the fallback behavior
    context "OSRelease is incomplete" do
      it "reads product information from OSRelease and then zypp and fills up internal variables" do
        release_name = "Happy Feet"
        release_version = "1.0.1"

        allow(Yast::OSRelease).to receive(:ReleaseName).and_return(release_name)
        allow(Yast::OSRelease).to receive(:ReleaseVersion).and_return(release_version)
        allow(Yast::OSRelease).to receive(:ReleaseInformation).and_return("")

        expect(Yast::Product.short_name).to eq("openSUSE")
        expect(Yast::Product.version).to eq("13.1")
        expect(Yast::Product.name).to eq("openSUSE (INSTALLED)")
      end
    end
  end

  context "while called on a running system without os-release file" do
    before(:each) do
      allow(Yast::Stage).to receive(:stage).and_return("normal")
      allow(Yast::Mode).to receive(:mode).and_return("normal")
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(false)
    end

    it "reads product information from zypp and fills up internal variables" do
      expect(Yast::Product.short_name).to eq("openSUSE")
      expect(Yast::Product.version).to eq("13.1")
      expect(Yast::Product.name).to eq("openSUSE (INSTALLED)")
    end
  end
end

# Describes Product methods
describe Yast::Product do
  before(:each) do
    stub_defaults
  end

  context "while called in installation without os-release file" do
    before(:each) do
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(false)
      allow(Yast::Stage).to receive(:stage).and_return("initial")
      allow(Yast::Mode).to receive(:mode).and_return("installation")
    end

    describe "#name" do
      it "reads data from zypp and returns product name" do
        expect(Yast::Product.name).to eq("openSUSE (SELECTED)")
      end
    end

    describe "#short_name" do
      it "reads data from zypp and returns short product name" do
        expect(Yast::Product.short_name).to eq("openSUSE")
      end
    end

    describe "#version" do
      it "reads data from zypp and returns product version" do
        expect(Yast::Product.version).to eq("13.1")
      end
    end

    describe "#run_you" do
      it "reads data from zypp and returns whether running online update is requested" do
        expect(Yast::Product.run_you).to eq(false)
      end
    end

    describe "#relnotesurl" do
      it "reads data from zypp and returns URL to release notes" do
        expect(Yast::Product.relnotesurl).to eq(
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm"
        )
      end
    end

    describe "#relnotesurl_all" do
      it "reads data from zypp and returns list of all URLs to release notes" do
        expect(Yast::Product.relnotesurl_all).to eq(
          ["http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm"]
        )
      end
    end

    describe "#product_of_relnotes" do
      it "reads data from zypp and returns hash of release notes URLs linking to their product names" do
        expect(Yast::Product.product_of_relnotes).to eq(
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm" => "openSUSE (SELECTED)"
        )
      end
    end

    describe "#FindBaseProducts" do
      it "reads data from zypp and returns list of base products selected for installation" do
        list_of_products = Yast::Product.FindBaseProducts

        expect(list_of_products).to be_a_kind_of(Array)
        expect(list_of_products[0]).to be_a_kind_of(Hash)
        expect(list_of_products[0]["display_name"]).to eq("openSUSE (SELECTED)")
        expect(list_of_products[0]["status"]).to eq(:selected)
      end
    end

    it "reports that method has been dropped" do
      [:vendor, :dist, :distproduct, :distversion, :shortlabel].each do |method_name|
        expect { Yast::Product.send(method_name) }.to raise_error(/#{method_name}.*dropped/)
      end
    end
  end

  context "while called on running system with os-release file" do
    release_name = "Mraky a Internety"
    release_version = "44.6"
    release_info = "#{release_name} #{release_version} (Banana Juice)"

    before(:each) do
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(true)
      allow(Yast::Stage).to receive(:stage).and_return("normal")
      allow(Yast::Mode).to receive(:mode).and_return("normal")

      allow(Yast::OSRelease).to receive(:ReleaseName).and_return(release_name)
      allow(Yast::OSRelease).to receive(:ReleaseVersion).and_return(release_version)
      allow(Yast::OSRelease).to receive(:ReleaseInformation).and_return(release_info)
    end

    describe "#name" do
      it "reads data from os-release and returns product name" do
        expect(Yast::Product.name).to eq(release_info)
      end
    end

    describe "#short_name" do
      it "reads data from os-release and returns short product name" do
        expect(Yast::Product.short_name).to eq(release_name)
      end
    end

    describe "#version" do
      it "reads data from os-release and returns product version" do
        expect(Yast::Product.version).to eq(release_version)
      end
    end

    describe "#run_you" do
      it "reads data from zypp and returns whether running online update is requested" do
        expect(Yast::Product.run_you).to eq(false)
      end
    end

    describe "#relnotesurl" do
      it "reads data from zypp and returns URL to release notes" do
        expect(Yast::Product.relnotesurl).to eq(
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm"
        )
      end
    end

    describe "#relnotesurl_all" do
      it "reads data from zypp and returns list of all URLs to release notes" do
        expect(Yast::Product.relnotesurl_all).to eq(
          ["http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm"]
        )
      end
    end

    describe "#product_of_relnotes" do
      it "reads data from zypp and returns hash of release notes URLs linking to their product names" do
        expect(Yast::Product.product_of_relnotes).to eq(
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm" => "openSUSE (INSTALLED)"
        )
      end
    end

    it "reports that method has been dropped" do
      [:vendor, :dist, :distproduct, :distversion, :shortlabel].each do |method_name|
        expect { Yast::Product.send(method_name) }.to raise_error(/#{method_name}.*dropped/)
      end
    end
  end

  # Methods that do not allow empty result
  SUPPORTED_METHODS = [:name, :short_name, :version, :run_you, :flags, :relnotesurl].freeze

  # Empty result is allowed
  SUPPORTED_METHODS_ALLOWED_EMPTY = [:relnotesurl_all, :product_of_relnotes].freeze

  context "while called on a broken system (no os-release, no zypp information)" do
    before(:each) do
      allow(Yast::OSRelease).to receive(:os_release_exists?).and_return(false)
      allow(Y2Packager::Resolvable).to receive(:find).with(kind: :product).and_return([])
      allow(Y2Packager::MediumType).to receive(:offline?).and_return(false)
      allow(Y2Packager::MediumType).to receive(:online?).and_return(true)
      allow(Y2Packager::MediumType).to receive(:type).and_return(:offline)
    end

    context "in installation" do
      it "reports that no base product was found" do
        allow(Yast::Stage).to receive(:stage).and_return("initial")
        allow(Yast::Mode).to receive(:mode).and_return("installation")

        # Logging evaluated product information
        expect(FileUtils).to receive(:mkdir_p).at_least(1).with(
          "/var/log/YaST2/installation_info/"
        )
        expect(File).to receive(:write).at_least(1).with(/no_base_product/, anything)

        SUPPORTED_METHODS.each do |method_name|
          Yast.y2milestone "Yast::Product.#{method_name}"
          expect { Yast::Product.send(method_name) }.to raise_error(/no base product found/i)
        end

        SUPPORTED_METHODS_ALLOWED_EMPTY.each do |method_name|
          Yast.y2milestone "Yast::Product.#{method_name}"
          expect(Yast::Product.send(method_name)).to be_empty
        end
      end
    end

    context "on a running system" do
      it "reports that no base product was found" do
        allow(Yast::Stage).to receive(:stage).and_return("normal")
        allow(Yast::Mode).to receive(:mode).and_return("normal")

        # Logging evaluated product information
        expect(FileUtils).to receive(:mkdir_p).at_least(1).with(
          "/var/log/YaST2/installation_info/"
        )
        expect(File).to receive(:write).at_least(1).with(/no_base_product/, anything)

        SUPPORTED_METHODS.each do |method_name|
          Yast.y2milestone "Yast::Product.#{method_name}"
          expect { Yast::Product.send(method_name) }.to raise_error(/no base product found/i)
        end

        SUPPORTED_METHODS_ALLOWED_EMPTY.each do |method_name|
          Yast.y2milestone "Yast::Product.#{method_name}"
          expect(Yast::Product.send(method_name)).to be_empty
        end
      end
    end
  end
end
