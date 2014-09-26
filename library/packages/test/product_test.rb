#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"
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

include Yast::Logger

# Path to a test data - service file - mocking the default data path
DATA_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "data")

def load_zypp(file_name)
  file_name = File.join(DATA_PATH, "zypp", file_name)

  raise "File not found: #{file_name}" unless File.exists?(file_name)

  log.info "Loading file: #{file_name}"
  YAML.load_file(file_name)
end

PRODUCTS_FROM_ZYPP = load_zypp('products.yml').freeze

def stub_defaults
    log.info "--------- Running test ---------"
    Yast::Product.send(:reset)
    Yast::PackageSystem.stub(:EnsureTargetInit).and_return(true)
    Yast::PackageSystem.stub(:EnsureSourceInit).and_return(true)
    Yast::Pkg.stub(:PkgSolve).and_return(true)
    Yast::PackageLock.stub(:Check).and_return(true)
    Yast::Pkg.stub(:ResolvableProperties).with("", :product, "").and_return(PRODUCTS_FROM_ZYPP.dup)
end

# Describes Product handling as a whole (due to lazy loading and internal caching),
# methods descriptions are below
describe "Yast::Product (integration)" do
  before(:each) do
    stub_defaults
  end

  context "while called in installation system without os-release file" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("initial")
      Yast::OSRelease.stub(:os_release_exists?).and_return(false)
    end

    describe "when the mode is Installation" do
      it "reads product information from zypp and fills up internal variables" do
        Yast::Mode.stub(:mode).and_return("installation")

        expect(Yast::Product.name).to                eq("openSUSE (SELECTED)")
        expect(Yast::Product.short_name).to          eq("openSUSE")
        expect(Yast::Product.version).to             eq("13.1")
      end
    end

    describe "when the mode is Update" do
      it "reads product information from zypp and fills up internal variables" do
        Yast::Mode.stub(:mode).and_return("update")

        expect(Yast::Product.name).to                eq("openSUSE (SELECTED)")
        expect(Yast::Product.short_name).to          eq("openSUSE")
        expect(Yast::Product.version).to             eq("13.1")
      end
    end
  end

  context "while called on a running system with os-release file" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("normal")
      Yast::Mode.stub(:mode).and_return("normal")
      Yast::OSRelease.stub(:os_release_exists?).and_return(true)
    end

    # This is the default behavior
    context "OSRelease is complete" do
      it "reads product information from OSRelease and fills up internal variables" do
        release_info = "Happy Feet 2.0"

        Yast::OSRelease.stub(:ReleaseName).and_return("anything")
        Yast::OSRelease.stub(:ReleaseVersion).and_return("anything")
        Yast::OSRelease.stub(:ReleaseInformation).and_return(release_info)

        expect(Yast::Product.name).to eq(release_info)
      end
    end

    # This is the fallback behavior
    context "OSRelease is incomplete" do
      it "reads product information from OSRelease and then zypp and fills up internal variables" do
        release_name = "Happy Feet"
        release_version = "1.0.1"

        Yast::OSRelease.stub(:ReleaseName).and_return(release_name)
        Yast::OSRelease.stub(:ReleaseVersion).and_return(release_version)
        Yast::OSRelease.stub(:ReleaseInformation).and_return("")

        expect(Yast::Product.short_name).to eq("openSUSE")
        expect(Yast::Product.version).to eq("13.1")
        expect(Yast::Product.name).to eq("openSUSE (INSTALLED)")
      end
    end
  end

  context "while called on a running system without os-release file" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("normal")
      Yast::Mode.stub(:mode).and_return("normal")
      Yast::OSRelease.stub(:os_release_exists?).and_return(false)
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
      Yast::OSRelease.stub(:os_release_exists?).and_return(false)
      Yast::Stage.stub(:stage).and_return("initial")
      Yast::Mode.stub(:mode).and_return("installation")
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
        expect(Yast::Product.product_of_relnotes).to eq({
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm" => "openSUSE (SELECTED)"
        })
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
        expect{ Yast::Product.send(method_name) }.to raise_error(/#{method_name}.*dropped/)
      end
    end
  end

  context "while called on running system with os-release file" do
    release_name = "Mraky a Internety"
    release_version = "44.6"
    release_info = "#{release_name} #{release_version} (Banana Juice)"

    before(:each) do
      Yast::OSRelease.stub(:os_release_exists?).and_return(true)
      Yast::Stage.stub(:stage).and_return("normal")
      Yast::Mode.stub(:mode).and_return("normal")

      Yast::OSRelease.stub(:ReleaseName).and_return(release_name)
      Yast::OSRelease.stub(:ReleaseVersion).and_return(release_version)
      Yast::OSRelease.stub(:ReleaseInformation).and_return(release_info)
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
        expect(Yast::Product.product_of_relnotes).to eq({
          "http://doc.opensuse.org/release-notes/x86_64/openSUSE/13.1/release-notes-openSUSE.rpm" => "openSUSE (INSTALLED)"
        })
      end
    end

    it "reports that method has been dropped" do
      [:vendor, :dist, :distproduct, :distversion, :shortlabel].each do |method_name|
        expect{ Yast::Product.send(method_name) }.to raise_error(/#{method_name}.*dropped/)
      end
    end
  end

  # Methods that do not allow empty result
  SUPPORTED_METHODS = [ :name, :short_name, :version, :run_you, :flags, :relnotesurl ]

  # Empty result is allowed
  SUPPORTED_METHODS_ALLOWED_EMPTY = [ :relnotesurl_all, :product_of_relnotes ]

  context "while called on a broken system (no os-release, no zypp information)" do
    before(:each) do
      Yast::OSRelease.stub(:os_release_exists?).and_return(false)
      Yast::Pkg.stub(:ResolvableProperties).with("", :product, "").and_return([])
    end

    context "in installation" do
      it "reports that no base product was found" do
        Yast::Stage.stub(:stage).and_return("initial")
        Yast::Mode.stub(:mode).and_return("installation")

        SUPPORTED_METHODS.each do |method_name|
          log.info "Yast::Product.#{method_name}"
          expect{ Yast::Product.send(method_name) }.to raise_error(/no base product found/i)
        end

        SUPPORTED_METHODS_ALLOWED_EMPTY.each do |method_name|
          log.info "Yast::Product.#{method_name}"
          expect(Yast::Product.send(method_name)).to be_empty
        end
      end
    end

    context "on a running system" do
      it "reports that no base product was found" do
        Yast::Stage.stub(:stage).and_return("normal")
        Yast::Mode.stub(:mode).and_return("normal")

        SUPPORTED_METHODS.each do |method_name|
          log.info "Yast::Product.#{method_name}"
          expect{ Yast::Product.send(method_name) }.to raise_error(/no base product found/i)
        end

        SUPPORTED_METHODS_ALLOWED_EMPTY.each do |method_name|
          log.info "Yast::Product.#{method_name}"
          expect(Yast::Product.send(method_name)).to be_empty
        end
      end
    end
  end

end
