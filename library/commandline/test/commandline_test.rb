#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "CommandLine"

describe Yast::CommandLine do
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
