#! /usr/bin/rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

# Important: Loads data in constructor
Yast.import "Product"

Yast.import "Mode"
Yast.import "Stage"
Yast.import "OSRelease"

include Yast::Logger

# Path to a test data - service file - mocking the default data path
DATA_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "data", "content_files")

SCR_PATH = Yast::Path.new(".content")

def load_content_file(file_name)
  file_name = File.join(DATA_PATH, file_name)

  raise "File not found: #{file_name}" unless File.exists?(file_name)

  Yast::log.warn("Unregistering agent #{SCR_PATH}")
  Yast::SCR.UnregisterAgent(SCR_PATH)

  Yast::log.warn("Registering new agent on #{SCR_PATH} for #{file_name}")
  raise "Cannot register SCR agent for #{file_name}" unless Yast::SCR.RegisterAgent(
    SCR_PATH,
    Yast::Term.new(:ag_ini,
      Yast::Term.new(
        :IniAgent,
        file_name,
        {
          "options"  => ["read_only", "global_values", "flat"],
          "comments" => ["^#.*", "^[ \t]*$"],
          "params"   => [
            { "match" => [ "^[ \t]*([^ \t]+)[ \t]*(.*)[ \t]*$", "%s %s" ] }
          ]
        }
      )
    )
  )
end

describe Yast::Product do
  context "while called in initial installation (content file exists)" do
    before(:each) do
      Yast::Product.stub(:can_use_content_file?).and_return(true)
      Yast::Product.stub(:can_use_os_release_file?).and_return(false)
    end

    it "reads product information from content file and fills up internal variables" do
      load_content_file("openSUSE_13.1_GM")
      Yast::Product.Product
      expect(Yast::Product.name).to                eq("openSUSE")
      expect(Yast::Product.short_name).to          eq("openSUSE")
      expect(Yast::Product.version).to             eq("13.1")
      expect(Yast::Product.vendor).to              eq("openSUSE")

      load_content_file("SLES_12_Beta4")
      Yast::Product.Product
      expect(Yast::Product.name).to                eq("SUSE Linux Enterprise Server 12")
      expect(Yast::Product.short_name).to          eq("SUSE Linux Enterprise Server 12")
      expect(Yast::Product.version).to             be_nil
      expect(Yast::Product.vendor).to              eq("SUSE")
    end
  end

  context "while called on a running system (os-release file exists)" do
    before(:each) do
      Yast::Product.stub(:can_use_content_file?).and_return(false)
      Yast::Product.stub(:can_use_os_release_file?).and_return(true)
    end

    it "reads product information from OSRelease and fills up internal variables" do
      release_name = "Happy Feet"
      release_version = "1.0.1"

      Yast::OSRelease.stub(:ReleaseName).and_return(release_name)
      Yast::OSRelease.stub(:ReleaseVersion).and_return(release_version)

      Yast::Product.Product
      expect(Yast::Product.short_name).to eq(release_name)
      expect(Yast::Product.version).to eq(release_version)
      expect(Yast::Product.name).to eq("#{release_name} #{release_version}")
    end
  end

  context "while called on a system with both content and os-release files supported" do
    before(:each) do
      Yast::Product.stub(:can_use_content_file?).and_return(true)
      Yast::Product.stub(:can_use_os_release_file?).and_return(true)
    end

    it "prefers os-release file to content file" do
      load_content_file("SLES_12_Beta4")

      release_name = "Happy Feet"
      release_version = "1.0.1"

      Yast::OSRelease.stub(:ReleaseName).and_return(release_name)
      Yast::OSRelease.stub(:ReleaseVersion).and_return(release_version)

      Yast::Product.Product
      expect(Yast::Product.name).to eq("#{release_name} #{release_version}")
      expect(Yast::Product.short_name).to eq(release_name)
      expect(Yast::Product.short_name).not_to eq("SUSE Linux Enterprise Server 12")
    end
  end

  context "while called on a broken system (neither content nor os-release file exists)" do
    before(:each) do
      Yast::Product.stub(:can_use_content_file?).and_return(false)
      Yast::Product.stub(:can_use_os_release_file?).and_return(false)
    end

    it "raises error while reading the product information" do
      expect { Yast::Product.Product }.to raise_error(/Cannot determine the product/)
    end
  end
end
