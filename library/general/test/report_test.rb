#! /usr/bin/env rspec
#
require_relative "test_helper"
require "yaml"

Yast.import "Report"
Yast.import "Mode"

describe Yast::Report do
  before { subject.ClearAll }

  describe ".Warning" do
    let(:show) { true }
    let(:message) { "Message" }

    context "while in command-line mode" do
      before(:each) do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "prints the message only on console" do
        expect(Yast::CommandLine).to receive("Print")
          .with(/#{message}/)
        expect(Yast::Popup).to_not receive("Warning")
        expect(Yast::Popup).to_not receive("TimedWarning")
        subject.Warning(message)
      end
    end

    context "while in UI mode and timeout is disabled" do
      let(:timeout) { 0 }

      before(:each) do
        subject.DisplayWarnings(show, timeout)
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "shows a popup" do
        expect(Yast::Popup).to receive("Warning").with(/#{message}/)
        subject.Warning(message)
      end
    end

    context "while in UI mode and timeout is enabled" do
      let(:timeout) { 1 }

      before(:each) do
        subject.DisplayWarnings(show, timeout)
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "shows timed popup" do
        expect(Yast::Popup).to receive("TimedWarning").with(/#{message}/, timeout)
        subject.Warning(message)
      end
    end
  end

  describe ".Error" do
    let(:show) { true }
    let(:message) { "Message" }

    context "while in command-line mode" do
      before(:each) do
        allow(Yast::Mode).to receive(:commandline).and_return(true)
      end

      it "prints the message only on console" do
        expect(Yast::CommandLine).to receive("Print")
          .with(/#{message}/)
        expect(Yast::Popup).to_not receive("Warning")
        expect(Yast::Popup).to_not receive("TimedWarning")
        subject.Error(message)
      end
    end

    context "while in UI mode and timeout is disabled" do
      let(:timeout) { 0 }

      before(:each) do
        subject.DisplayErrors(show, timeout)
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "shows a popup" do
        expect(Yast::Popup).to receive("Error").with(/#{message}/)
        subject.Error(message)
      end
    end

    context "while in UI mode and timeout is enabled" do
      let(:timeout) { 1 }

      before(:each) do
        subject.DisplayErrors(show, timeout)
        allow(Yast::Mode).to receive(:commandline).and_return(false)
      end

      it "shows a timed popup" do
        expect(Yast::Popup).to receive("TimedError").with(/#{message}/, timeout)
        subject.Error(message)
      end
    end
  end
end
