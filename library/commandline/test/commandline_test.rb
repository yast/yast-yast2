#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "CommandLine"

describe Yast::CommandLine do
  # restore the original modes to not accidentally influence the other tests
  # (these tests change the UI mode to "commandline")
  around(:example) do |example|
    orig_mode = Yast::Mode.mode
    orig_ui = Yast::Mode.ui
    example.run
    Yast::Mode.SetMode(orig_mode)
    Yast::Mode.SetUI(orig_ui)
  end

  before do
    allow(Yast::Debugger).to receive(:installed?).and_return(false)
  end

  it "invokes initialize, handler and finish" do
    expect(STDOUT).to receive(:puts).with("Initialize called").ordered
    expect(STDOUT).to receive(:puts).with("something").ordered
    expect(STDOUT).to receive(:puts).with("Finish called").ordered

    Yast::WFM.CallFunction("dummy_cmdline", ["echo", "text=something"])
  end

  it "displays errors and aborts" do
    expect(STDOUT).to receive(:puts).with("Initialize called").ordered
    expect(Yast::CommandLine).to receive(:Print).with(/I crashed/).ordered
    expect(STDOUT).to_not receive(:puts).with("Finish called")

    Yast::WFM.CallFunction("dummy_cmdline", ["crash"])
  end
end
