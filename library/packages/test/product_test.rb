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
  context "while called in initial installation" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("initial")
      Yast::Mode.stub(:mode).and_return("installation")
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

  context "while called in initial update" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("initial")
      Yast::Mode.stub(:mode).and_return("update")
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

  context "while called on a running system in AutoYast" do
    before(:each) do
      Yast::Stage.stub(:stage).and_return("normal")
      Yast::Mode.stub(:mode).and_return("autoinst_config")
    end

    it "reads reads product information from OSRelease and fills up internal variables" do
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
end
