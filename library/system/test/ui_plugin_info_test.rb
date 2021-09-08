#! /usr/bin/env rspec

require_relative "./test_helper"
require "yast2/ui_plugin_info"

PROC_MAPS_PATH = File.join(__dir__, "data/proc-maps")

def stored_proc_maps(scenario)
  File.join(PROC_MAPS_PATH, "proc-maps-#{scenario}")
end

describe Yast::UiPluginInfo do
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
end
