#! /usr/bin/env rspec

require_relative "test_helper"
require "yast2/ui_plugin_info"

PROC_MAPS_PATH = File.join(__dir__, "data/proc-maps")

def stored_proc_maps(scenario)
  File.join(PROC_MAPS_PATH, "proc-maps-#{scenario}")
end

describe Yast::UIPluginInfo do
  describe "#new" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_plugins).to eq []
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "finds the Qt UI plug-in" do
        expect(subject.ui_plugins).to eq ["/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end

    context "with the Qt UI + Qt-Pkg" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "finds the Qt UI plug-in and the Qt-Pkg plug-in" do
        expect(subject.ui_plugins).to eq ["/usr/lib64/yui/libyui-qt-pkg.so.15.0.0", "/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end
  end

  describe "#main_ui_plugin" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.main_ui_plugin).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "identifies the UI as \"qt\"" do
        expect(subject.main_ui_plugin).to eq "qt"
      end
    end

    context "with the Qt UI + Qt-Pkg extension" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "identifies the UI as \"qt\"" do
        expect(subject.main_ui_plugin).to eq "qt"
      end
    end

    context "with the Qt UI + Qt-Graph extension" do
      let(:maps_file) { stored_proc_maps("qt-graph") }

      it "identifies the UI as \"qt\"" do
        expect(subject.main_ui_plugin).to eq "qt"
      end
    end

    context "with the NCurses UI" do
      let(:maps_file) { stored_proc_maps("ncurses") }

      it "identifies the UI as \"ncurses\"" do
        expect(subject.main_ui_plugin).to eq "ncurses"
      end
    end

    context "with the NCurses UI + NCurses-Pkg extension" do
      let(:maps_file) { stored_proc_maps("ncurses") }

      it "identifies the UI as \"ncurses\"" do
        expect(subject.main_ui_plugin).to eq "ncurses"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil for the UI" do
        expect(subject.main_ui_plugin).to eq nil
      end
    end
  end

  describe "#main_ui_plugin_complete" do
    let(:subject) { described_class.new(maps_file) }

    # Just one context for this since the other cases are implicitly already
    # tested with main_ui_plugin
    context "with the Qt UI + Qt-Pkg extension" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "identifies the UI as \"/usr/lib64/yui/libyui-qt.so.15.0.0\"" do
        expect(subject.main_ui_plugin_complete).to eq "/usr/lib64/yui/libyui-qt.so.15.0.0"
      end
    end
  end

  describe "#ui_so_number" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_so_number).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "identifies the UI SO number as 15.0.0" do
        expect(subject.ui_so_number).to eq "15.0.0"
      end
    end

    context "with the Qt UI + Qt-Pkg extension" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "identifies the UI SO number as 15.0.0" do
        expect(subject.ui_so_number).to eq "15.0.0"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil" do
        expect(subject.ui_so_number).to eq nil
      end
    end
  end

  describe "#ui_so_major" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_so_major).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "identifies the UI SO major number as 15" do
        expect(subject.ui_so_major).to eq "15"
      end
    end

    context "with the Qt UI + Qt-Pkg extension" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "identifies the UI SO major number as 15" do
        expect(subject.ui_so_major).to eq "15"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil" do
        expect(subject.ui_so_major).to eq nil
      end
    end
  end

  describe "#ui_extension_plugin" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_extension_plugin("pkg")).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "returns the -pkg counterpart" do
        expect(subject.ui_extension_plugin("pkg")).to eq "libyui-qt-pkg.so.15.0.0"
      end
    end

    context "with the Qt UI + Qt-Graph extension" do
      let(:maps_file) { stored_proc_maps("qt-graph") }

      it "returns the -pkg counterpart" do
        expect(subject.ui_extension_plugin("pkg")).to eq "libyui-qt-pkg.so.15.0.0"
      end
    end

    context "with the NCurses UI" do
      let(:maps_file) { stored_proc_maps("ncurses") }

      it "returns the -pkg counterpart" do
        expect(subject.ui_extension_plugin("pkg")).to eq "libyui-ncurses-pkg.so.15.0.0"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil" do
        expect(subject.ui_extension_plugin("pkg")).to eq nil
      end
    end
  end

  describe "#ui_extension_plugin_complete" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_extension_plugin_complete("pkg")).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "returns the -pkg counterpart" do
        expect(subject.ui_extension_plugin_complete("pkg")).to eq "/usr/lib64/yui/libyui-qt-pkg.so.15.0.0"
      end
    end

    context "with the NCurses UI" do
      let(:maps_file) { stored_proc_maps("ncurses") }

      it "returns the -pkg counterpart" do
        expect(subject.ui_extension_plugin_complete("pkg")).to eq "/usr/lib64/yui/libyui-ncurses-pkg.so.15.0.0"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil" do
        expect(subject.ui_extension_plugin_complete("pkg")).to eq nil
      end
    end
  end

  describe "#ui_extension_pkg" do
    let(:subject) { described_class.new(maps_file) }

    context "empty" do
      let(:maps_file) { nil }

      it "does not crash and burn" do
        expect(subject.ui_extension_pkg("pkg")).to eq nil
      end
    end

    context "with the Qt UI" do
      let(:maps_file) { stored_proc_maps("qt") }

      it "returns the correct package name for the -pkg UI extension" do
        expect(subject.ui_extension_pkg("pkg")).to eq "libyui-qt-pkg15"
      end

      it "returns the correct package name for the -graph UI extension" do
        expect(subject.ui_extension_pkg("graph")).to eq "libyui-qt-graph15"
      end
    end

    context "with the NCurses UI" do
      let(:maps_file) { stored_proc_maps("ncurses") }

      it "returns the correct package name for the -pkg UI extension" do
        expect(subject.ui_extension_pkg("pkg")).to eq "libyui-ncurses-pkg15"
      end
    end

    context "without any UI" do
      let(:maps_file) { stored_proc_maps("no-ui") }

      it "returns nil" do
        expect(subject.ui_extension_pkg("pkg")).to eq nil
      end
    end
  end
end
