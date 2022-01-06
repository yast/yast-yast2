#! /usr/bin/env rspec

require_relative "../test_helper"
require "ui/ui_extension_checker"

describe Yast::UIExtensionChecker do
  describe "#new" do
    let(:ui) { "qt" }
    let(:ext) { "pkg" }
    let(:ext_plugin) { "/my/yui/libyui-qt-pkg-42" }
    let(:ext_pkg) { "libyui-qt-pkg42" }
    let(:ui_plugin_info) do
      instance_double(Yast::UIPluginInfo,
        main_ui_plugin:               ui,
        ui_extension_plugin_complete: ext_plugin,
        ui_extension_pkg:             ext_pkg)
    end
    subject { described_class.new(ext) }

    before do
      allow(Yast::UIPluginInfo).to receive(:new).and_return(ui_plugin_info)
      allow(File).to receive(:exist?).and_return(plugin_found)
    end

    context "extension plug-in binary found" do
      let(:plugin_found) { true }

      it "no pop-up is opened, and it reports ok" do
        expect(Yast::Popup).not_to receive(:ContinueCancel)
        expect(Yast::Report).not_to receive(:Error)
        expect(subject.ok?).to be true
      end
    end

    context "extension plug-in binary not found" do
      let(:confirm?) { false }
      let(:plugin_found) { false }
      before do
        allow(Yast::Popup).to receive(:ContinueCancel).and_return(confirm?)
      end

      it "opens a pop-up to ask if the package should be installed" do
        expect(Yast::Popup).to receive(:ContinueCancel).with(/package.*install/)
        subject
      end

      context "and the user does not confirm to install the package" do
        it "reports not ok" do
          expect(subject.ok?).to be false
        end
      end

      context "and the confirms to install the package" do
        let(:confirm?) { true }
        let(:pkg_install_ok?) { true }
        before do
          allow(Yast::Package).to receive(:DoInstall).and_return(pkg_install_ok?)
        end

        it "installs the package and reports ok if it could be installed" do
          expect(Yast::Package).to receive(:DoInstall).and_return(true)
          expect(subject.ok?).to be true
        end

        context "the package could not be installed" do
          let(:pkg_install_ok?) { false }
          before do
            allow(Yast::Report).to receive(:Error)
          end

          it "reports an error" do
            expect(Yast::Report).to receive(:Error).with(/could not be installed/)
            expect(subject.ok?).to be false
          end
        end
      end

      context "UI extension not available" do
        let(:ext) { "foo" }
        before do
          allow(Yast::Report).to receive(:Error)
        end

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/not available/)
          expect(subject.ok?).to be false
        end
      end
    end
  end
end
