#! /usr/bin/env rspec
# typed: false

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

  # NOTE: when using the byebug debugger here temporarily comment out
  # all "expect($stdout)" lines otherwise the byebug output will be
  # lost in the rspec mocks and you won't see anything.

  it "invokes initialize, handler and finish" do
    expect($stdout).to receive(:puts).with("Initialize called").ordered
    expect($stdout).to receive(:puts).with("something").ordered
    expect($stdout).to receive(:puts).with("Finish called").ordered

    Yast::WFM.CallFunction("dummy_cmdline", ["echo", "text=something"])
  end

  it "displays errors and aborts" do
    expect($stdout).to receive(:puts).with("Initialize called").ordered
    expect(Yast::CommandLine).to receive(:Print).with(/I crashed/).ordered
    expect($stdout).to_not receive(:puts).with("Finish called")

    Yast::WFM.CallFunction("dummy_cmdline", ["crash"])
  end
end
