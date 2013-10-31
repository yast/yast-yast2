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
    it "tests whether module is loaded on boot" do
      ["module-a", "module-b", "user-module-1", "user-module-2", "user-module-3", "user-module-4"].each do |kernel_module|
        expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_true
      end

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

    it "adds module only once" do
      new_module = "new-kernel-module"
      Yast::Kernel.AddModuleToLoad new_module
      Yast::Kernel.AddModuleToLoad new_module
      expect(Yast::Kernel.modules_to_load.values.flatten.select{|m| m == new_module}.size).to eq(1)
    end
  end

  describe "#RemoveModuleToLoad" do
    it "removes module from list of modules to be loaded on boot" do
      module_to_remove = "user-module-2"
      expect(Yast::Kernel.module_to_be_loaded?(module_to_remove)).to be_true
      Yast::Kernel.RemoveModuleToLoad module_to_remove
      expect(Yast::Kernel.module_to_be_loaded?(module_to_remove)).to be_false
    end

    it "does not remove module which is not in list" do
      module_to_remove = "not-in-list"
      expect(Yast::Kernel.module_to_be_loaded?(module_to_remove)).to be_false
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

        new_module = "new-kernel-module"
        remove_module = "user-module-2"

        # Modifying data
        Yast::Kernel.AddModuleToLoad new_module
        Yast::Kernel.RemoveModuleToLoad remove_module

        expect(Yast::Kernel.SaveModulesToLoad).to be_true

        # Tests on the stored modified data
        Yast::Kernel.reset_modules_to_load
        ["module-a", "module-b", "user-module-1", "user-module-3", "user-module-4", new_module].each do |kernel_module|
          expect(Yast::Kernel.module_to_be_loaded?(kernel_module)).to be_true
        end

        expect(Yast::Kernel.module_to_be_loaded?(remove_module)).to be_false

        # Tests directly on the system
        number_of_nkm = `grep --count --no-filename #{new_module} #{tmpdir}/*`
        expect(number_of_nkm.split.map(&:to_i).inject(:+)).to eq(1)

        number_of_rkm = `grep --count --no-filename #{remove_module} #{tmpdir}/*`
        expect(number_of_rkm.split.map(&:to_i).inject(:+)).to eq(0)
      end
    end
  end

end
