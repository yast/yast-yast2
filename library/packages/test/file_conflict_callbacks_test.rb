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

  # run this command in "irb -ryast" to obtain the method names:
  # Yast.import "Pkg"; Yast::Pkg.methods.select {|m| m.to_s.start_with?("Callback")}
  # (Remove the methods which are defined above.)
  MOCK_METHODS = [
    :CallbackAcceptFileWithoutChecksum,
    :CallbackAcceptUnknownDigest,
    :CallbackAcceptUnknownGpgKey,
    :CallbackAcceptUnsignedFile,
    :CallbackAcceptVerificationFailed,
    :CallbackAcceptWrongDigest,
    :CallbackAuthentication,
    :CallbackDestDownload,
    :CallbackDoneDownload,
    :CallbackDonePackage,
    :CallbackDoneProvide,
    :CallbackDoneRefresh,
    :CallbackDoneScanDb,
    :CallbackErrorScanDb,
    :CallbackFinishDeltaApply,
    :CallbackFinishDeltaDownload,
    :CallbackImportGpgKey,
    :CallbackInitDownload,
    :CallbackMediaChange,
    :CallbackMessage,
    :CallbackNotifyConvertDb,
    :CallbackNotifyRebuildDb,
    :CallbackPkgGpgCheck,
    :CallbackProblemDeltaApply,
    :CallbackProblemDeltaDownload,
    :CallbackProcessDone,
    :CallbackProcessNextStage,
    :CallbackProcessProgress,
    :CallbackProcessStart,
    :CallbackProgressConvertDb,
    :CallbackProgressDeltaApply,
    :CallbackProgressDeltaDownload,
    :CallbackProgressDownload,
    :CallbackProgressPackage,
    :CallbackProgressProvide,
    :CallbackProgressRebuildDb,
    :CallbackProgressReportEnd,
    :CallbackProgressReportProgress,
    :CallbackProgressReportStart,
    :CallbackProgressScanDb,
    :CallbackResolvableReport,
    :CallbackScriptFinish,
    :CallbackScriptProblem,
    :CallbackScriptProgress,
    :CallbackScriptStart,
    :CallbackSourceChange,
    :CallbackSourceCreateDestroy,
    :CallbackSourceCreateEnd,
    :CallbackSourceCreateError,
    :CallbackSourceCreateInit,
    :CallbackSourceCreateProgress,
    :CallbackSourceCreateStart,
    :CallbackSourceProbeEnd,
    :CallbackSourceProbeError,
    :CallbackSourceProbeFailed,
    :CallbackSourceProbeProgress,
    :CallbackSourceProbeStart,
    :CallbackSourceProbeSucceeded,
    :CallbackSourceReportDestroy,
    :CallbackSourceReportEnd,
    :CallbackSourceReportError,
    :CallbackSourceReportInit,
    :CallbackSourceReportProgress,
    :CallbackSourceReportStart,
    :CallbackStartConvertDb,
    :CallbackStartDeltaApply,
    :CallbackStartDeltaDownload,
    :CallbackStartDownload,
    :CallbackStartPackage,
    :CallbackStartProvide,
    :CallbackStartRebuildDb,
    :CallbackStartRefresh,
    :CallbackStartScanDb,
    :CallbackStopConvertDb,
    :CallbackStopRebuildDb,
    :CallbackTrustedKeyAdded,
    :CallbackTrustedKeyRemoved
  ].freeze

  MOCK_METHODS.each do |method|
    define_method(method) { |arg| } # mock empty methods with a single argument
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
    context "in UI mode" do
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "calls the Pkg methods for registering the file conflicts handlers" do
        expect(dummy_pkg).to receive(:CallbackFileConflictStart).at_least(:once)
        expect(dummy_pkg).to receive(:CallbackFileConflictProgress).at_least(:once)
        expect(dummy_pkg).to receive(:CallbackFileConflictReport).at_least(:once)
        expect(dummy_pkg).to receive(:CallbackFileConflictFinish).at_least(:once)

        Packages::FileConflictCallbacks.register
      end
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
  end

  describe "the registered progress callback handler" do
    let(:start_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_start
    end

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
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "receives the progress call" do
        expect_any_instance_of(Yast::DelayedProgressPopup).to receive(:progress)

        start_cb.call
        progress_cb.call(progress)
      end

      context "when the delayed progress popup is open" do
        before do
          allow_any_instance_of(Yast::DelayedProgressPopup).to receive(:open?).and_return(true)
        end

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
      end

      context "when the delayed progress popup is NOT open" do
        before do
          allow_any_instance_of(Yast::DelayedProgressPopup).to receive(:open?).and_return(false)
        end

        it "does not ask for user input" do
          expect(Yast::UI).to_not receive(:PollInput)
        end

        it "returns true to continue" do
          expect(progress_cb.call(progress)).to eq(true)
        end
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
          allow(Yast::Mode).to receive(:commandline).and_return(false)
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
    let(:start_cb) do
      Packages::FileConflictCallbacks.register
      dummy_pkg.fc_start
    end

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
      before do
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "closes the delayed progress popup" do
        expect_any_instance_of(Yast::DelayedProgressPopup).to receive(:close)

        start_cb.call
        finish_cb.call
      end
    end
  end
end
