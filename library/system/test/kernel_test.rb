#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "tmpdir"

include Yast

Yast.import "Kernel"

DEFAULT_DATA_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "data/modules.d")

describe "Kernel" do
  before (:each) do
    stub_const("Yast::KernelClass::MODULES_DIR", DEFAULT_DATA_DIR)
    @default_modules = {
      Yast::KernelClass::MODULES_CONF_FILE => [],
      "MODULES_LOADED_ON_BOOT.conf"=>["module-a", "module-b"],
      "user-added-1.conf" => ["user-module-1", "user-module-2", "user-module-3"],
      "user-added-2.conf"=>["user-module-4"],
    }
    Yast::Kernel.reset_modules_to_load
  end

  describe "#modules_to_load" do
    it "returns hash of modules to load" do
      expect(Yast::Kernel.modules_to_load).to eq(@default_modules)
    end
  end

  describe "#module_to_be_loaded?" do
    it "ensures that modules are listed within modules to be loaded on boot" do
      ["module-a", "module-b", "user-module-1", "user-module-2", "user-module-3", "user-module-4"].each do |kernel_module|
        expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_true
      end
    end

    it "checks that other modules are not listed within modules to be loaded on boot" do
      ["module-c", "user-module-5"].each do |kernel_module|
        expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_false
      end
    end
  end

  describe "#AddModuleToLoad" do
    it "adds new module to be loaded on boot" do
      new_module = "new-kernel-module"
      expect(Yast::Kernel.module_to_be_loaded?(new_module)).to be_false
      Yast::Kernel.AddModuleToLoad new_module
      expect(Yast::Kernel.module_to_be_loaded?(new_module)).to be_true
    end
  end

  describe "#RemoveModuleToLoad" do
    it "removes module from list of modules to be loaded on boot" do
      module_to_remove = "user-module-2"
      expect(Yast::Kernel.module_to_be_loaded?(module_to_remove)).to be_true
      Yast::Kernel.RemoveModuleToLoad module_to_remove
      expect(Yast::Kernel.module_to_be_loaded?(module_to_remove)).to be_false
    end
  end

  describe "#SaveModulesToLoad" do
    it "stores all modules to be loaded to configuration files" do
      Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r(DEFAULT_DATA_DIR + "/.", tmpdir)

        stub_const("Yast::KernelClass::MODULES_DIR", tmpdir)
        Yast::Kernel.reset_modules_to_load

        # Tests on the default data
        ["module-a", "module-b", "user-module-1", "user-module-2", "user-module-3", "user-module-4"].each do |kernel_module|
          expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_true
        end

        # Modifying data
        Yast::Kernel.AddModuleToLoad "new-kernel-module"
        Yast::Kernel.RemoveModuleToLoad "user-module-2"

        expect(Yast::Kernel.SaveModulesToLoad).to be_true

        # Tests on the stored modified data
        Yast::Kernel.reset_modules_to_load
        ["module-a", "module-b", "user-module-1", "user-module-3", "user-module-4", "new-kernel-module"].each do |kernel_module|
          expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_true
        end
      end
    end
  end

end
