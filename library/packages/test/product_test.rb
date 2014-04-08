#! /usr/bin/rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

# Important: Loads data in constructor
Yast.import "Product"

Yast.import "SCR"
Yast.import "Mode"
Yast.import "Stage"
Yast.import "UI"

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
  context "while running in initial installation or update" do
    before(:each) do
      Yast::Stage.stub(:initial).and_return(true)
      Yast::Mode.stub(:live_installation).and_return(false)
    end

    it "reads product information and fills up internal variables" do
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
end
