#! /usr/bin/env rspec

require_relative "test_helper"

require "packages/file_conflict_callbacks"

# a helper class to replace Yast::Pkg
class DummyPkg
  # remember the registered file conflict callback handlers to test them later
  attr_reader :fc_start, :fc_progress, :fc_report, :fc_finish

  def CallbackFileConflictStart(func)
    @fc_start = func
  end

  def CallbackFileConflictProgress(func)
    @fc_progress = func
  end

  def CallbackFileConflictReport(func)
    @fc_report = func
  end

  def CallbackFileConflictFinish(func)
    @fc_finish = func
  end
end

describe Packages::FileConflictCallbacks do
  let(:dummy_pkg) { DummyPkg.new }

  before do
    # catch all callbacks registration calls via this Pkg replacement
    stub_const("Yast::Pkg", dummy_pkg)

    # stub console printing
    Yast.import "CommandLine"
    allow(Yast::CommandLine).to receive(:Print)
    allow(Yast::CommandLine).to receive(:PrintVerbose)
    allow(Yast::CommandLine).to receive(:PrintVerboseNoCR)
  end

  describe ".register" do
    it "calls the Pkg methods for registering the file conflicts handlers" do
      expect(dummy_pkg).to receive(:CallbackFileConflictStart)
      expect(dummy_pkg).to receive(:CallbackFileConflictProgress)
      expect(dummy_pkg).to receive(:CallbackFileConflictReport)
      expect(dummy_pkg).to receive(:CallbackFileConflictFinish)

      Packages::FileConflictCallbacks.register
    end
  end

  describe "the registered start callback handler" do
    let(:start_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_start
    end

    context "in the command line mode" do
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "does not call any UI method" do
        ui = double("no method call expected")
        stub_const("Yast::UI", ui)

        start_cb.call
      end
    end

    context "in UI mode" do
      it "reuses the package installation progress" do
        expect(Yast::UI).to receive(:WidgetExists).and_return(true)
        expect(Yast::UI).to receive(:ChangeWidget).twice

        start_cb.call
      end

      it "opens a new progress if installation progress was not displayed" do
        expect(Yast::UI).to receive(:WidgetExists).and_return(false)
        expect(Yast::Wizard).to receive(:CreateDialog)
        expect(Yast::Progress).to receive(:Simple)

        start_cb.call
      end
    end
  end

  describe "the registered progress callback handler" do
    let(:progress_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_progress
    end

    # fake progress value (percent)
    let(:progress) { 42 }

    context "in the command line mode" do
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "does not call any UI method" do
        ui = double("no method call expected")
        stub_const("Yast::UI", ui)

        progress_cb.call(progress)
      end

      it "prints the current progress" do
        expect(Yast::CommandLine).to receive(:PrintVerboseNoCR).with(/42%/)

        progress_cb.call(progress)
      end

      it "returns true to continue" do
        expect(progress_cb.call(progress)).to eq(true)
      end
    end

    context "in UI mode" do
      it "returns false to abort if user clicks Abort" do
        expect(Yast::UI).to receive(:PollInput).and_return(:abort)

        expect(progress_cb.call(progress)).to eq(false)
      end

      it "returns true to continue when no user input" do
        expect(Yast::UI).to receive(:PollInput).and_return(nil)

        expect(progress_cb.call(progress)).to eq(true)
      end

      it "returns true to continue on unknown user input" do
        expect(Yast::UI).to receive(:PollInput).and_return(:next)

        expect(progress_cb.call(progress)).to eq(true)
      end

      it "uses the existing widget if package installation progress was displayed" do
        expect(Yast::UI).to receive(:WidgetExists).and_return(true)
        expect(Yast::UI).to receive(:ChangeWidget)

        progress_cb.call(progress)
      end

      it "sets the progress if package installation progress was not displayed" do
        expect(Yast::UI).to receive(:WidgetExists).and_return(false)
        expect(Yast::Progress).to receive(:Step).with(progress)

        progress_cb.call(progress)
      end
    end
  end

  describe "the registered report callback handler" do
    let(:report_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_report
    end

    context "no conflict found" do
      let(:conflicts) { [] }
      let(:excluded) { [] }

      before do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "does not check the command line mode, it behaves same as in the UI mode" do
        expect(Yast::Mode).to_not receive(:commandline)
        report_cb.call(excluded, conflicts)
      end

      it "does not call any UI method" do
        ui = double("no method call expected")
        stub_const("Yast::UI", ui)

        report_cb.call(excluded, conflicts)
      end

      it "returns true to continue" do
        expect(report_cb.call(excluded, conflicts)).to eq(true)
      end
    end

    context "conflicts found" do
      let(:conflicts) { ["conflict1!", "conflict2!"] }
      let(:excluded) { [] }

      context "in the command line mode" do
        before do
          allow(Yast::Mode).to receive(:commandline).and_return(true)
        end

        it "does not call any UI method" do
          ui = double("no method call expected")
          stub_const("Yast::UI", ui)

          report_cb.call(excluded, conflicts)
        end

        it "prints the found conflicts" do
          expect(Yast::Report).to receive(:Error)

          report_cb.call(excluded, conflicts)
        end

        it "returns true to continue" do
          expect(report_cb.call(excluded, conflicts)).to eq(true)
        end
      end

      context "in AutoYaST mode" do
        before do
          expect(Yast::Mode).to receive(:auto).and_return(true)
          allow(Yast::Report).to receive(:Error)
        end

        it "reporrts the found conflicts" do
          expect(Yast::Report).to receive(:Error)

          report_cb.call(excluded, conflicts)
        end

        it "returns true to continue" do
          expect(report_cb.call(excluded, conflicts)).to eq(true)
        end
      end

      context "in UI mode" do
        before do
          allow(Yast::UI).to receive(:OpenDialog)
          allow(Yast::UI).to receive(:CloseDialog)
          allow(Yast::UI).to receive(:SetFocus)
        end

        it "opens a Popup dialog, waits for user input and closes the dialog" do
          expect(Yast::UI).to receive(:OpenDialog).ordered
          expect(Yast::UI).to receive(:UserInput).ordered
          expect(Yast::UI).to receive(:CloseDialog).ordered

          report_cb.call(excluded, conflicts)
        end

        it "returns false to abort if user clicks Abort" do
          expect(Yast::UI).to receive(:UserInput).and_return(:abort)

          expect(report_cb.call(excluded, conflicts)).to eq(false)
        end

        it "returns true to continue if user clicks Continue" do
          expect(Yast::UI).to receive(:UserInput).and_return(:continue)

          expect(report_cb.call(excluded, conflicts)).to eq(true)
        end
      end
    end
  end

  describe "the registered finish callback handler" do
    let(:finish_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_finish
    end

    context "in the command line mode" do
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "does not call any UI method" do
        ui = double("no method call expected")
        stub_const("Yast::UI", ui)

        finish_cb.call
      end
    end

    context "in UI mode" do
      it "no change if installation progress was already displayed" do
        ui = double("no method call expected", WidgetExists: true)
        stub_const("Yast::UI", ui)

        finish_cb.call
      end

      it "closes progress if installation progress was not displayed" do
        allow(Yast::UI).to receive(:WidgetExists).and_return(false)
        expect(Yast::Wizard).to receive(:CloseDialog)
        expect(Yast::Progress).to receive(:Finish)

        finish_cb.call
      end

    end
  end
end
