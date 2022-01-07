#! /usr/bin/env rspec

require_relative "./test_helper"
require "yast2/shared_lib_info"

PROC_MAPS_PATH = File.join(__dir__, "data/proc-maps")

def stored_proc_maps(scenario)
  File.join(PROC_MAPS_PATH, "proc-maps-#{scenario}")
end

describe Yast::SharedLibInfo do
  describe "#new" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.shared_libs).to eq []
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "finds all the shared libs" do
        expect(subject.shared_libs.size).to eq 117
      end

      it "finds the Qt UI plug-in" do
        ui_plugins = subject.shared_libs.grep(/yui\/libyui/)
        expect(ui_plugins).to eq ["/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end

    context "with the Qt UI + Qt-Pkg" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "finds the Qt UI plug-in and the Qt-Pkg plug-in" do
        ui_plugins = subject.shared_libs.grep(/yui\/libyui/)
        expect(ui_plugins).to eq ["/usr/lib64/yui/libyui-qt-pkg.so.15.0.0", "/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end
  end

  describe "#split_lib_name" do
    it "survives nil" do
      expect(described_class.split_lib_name(nil)).to eq nil
    end

    it "survives an empty string" do
      expect(described_class.split_lib_name("")).to eq []
    end

    it "correctly splits a UI plug-in path" do
      expect(described_class.split_lib_name("/usr/lib64/yui/libyui-qt-pkg.so.15.0.0")).to eq ["libyui-qt-pkg", "15.0.0"]
    end

    it "correctly splits a libc path without a SO number" do
      expect(described_class.split_lib_name("/usr/lib64/libc-2.33.so")).to eq ["libc-2.33"]
    end
  end

  describe "#lib_basename" do
    it "survives nil" do
      expect(described_class.lib_basename(nil)).to eq nil
    end

    it "correctly returns the lib name of a UI plug-in path" do
      expect(described_class.lib_basename("/usr/lib64/yui/libyui-qt-pkg.so.15.0.0")).to eq "libyui-qt-pkg"
    end

    it "correctly returns the lib name of a libc path without a SO number" do
      expect(described_class.lib_basename("/usr/lib64/libc-2.33.so")).to eq "libc-2.33"
    end
  end

  describe "#so_number" do
    it "survives nil" do
      expect(described_class.so_number(nil)).to eq nil
    end

    it "correctly returns the SO number of a UI plug-in path" do
      expect(described_class.so_number("/usr/lib64/yui/libyui-qt-pkg.so.15.0.0")).to eq "15.0.0"
    end

    it "correctly returns nil if the lib does not have a SO number" do
      expect(described_class.so_number("/usr/lib64/libc-2.33.so")).to eq nil
    end
  end

  describe "#so_major" do
    it "correctly returns the SO number of a UI plug-in path" do
      expect(described_class.so_number("/usr/lib64/yui/libyui-qt-pkg.so.15.0.0")).to eq "15.0.0"
    end

    it "correctly returns nil if the lib does not have a SO number" do
      expect(described_class.so_number("/usr/lib64/libc-2.33.so")).to eq nil
    end
  end

  describe "#build_lib_name" do
    it "correctly builds a UI plug-in name" do
      expect(described_class.build_lib_name("libyui-qt-pkg", "15.0.0")).to eq "libyui-qt-pkg.so.15.0.0"
    end

    it "correctly builds a libc path without a SO number" do
      expect(described_class.build_lib_name("libc-2.33", nil)).to eq "libc-2.33.so"
    end
  end
end
