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

      it "finds a lot of shared libs" do
        expect(subject.shared_libs.size).to eq 117
      end

      it "finds the Qt UI plug-in" do
        ui_plugins = subject.shared_libs.select { |p| p =~ /yui\/libyui/ }
        expect(ui_plugins).to eq ["/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end

    context "with the Qt UI + Qt-Pkg" do
      let(:maps_file) { stored_proc_maps("qt-pkg") }

      it "finds the Qt UI plug-in and the Qt-Pkg plug-in" do
        ui_plugins = subject.shared_libs.select { |p| p =~ /yui\/libyui/ }
        expect(ui_plugins).to eq ["/usr/lib64/yui/libyui-qt-pkg.so.15.0.0", "/usr/lib64/yui/libyui-qt.so.15.0.0"]
      end
    end
  end

end
