#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

describe "Hostname#CurrentFQ" do
  Yast.import "Hostname"
  Yast.import "FileUtils"

  let(:etc_hostname) { "etc.hostname.cz" }
  let(:cmd_hostname) { "cmd.hostname.cz" }

  it "returns output of hostname --fqdn if available" do
    allow(Yast::SCR)
      .to receive(:Execute)
      .with(path(".target.bash_output"), "hostname --fqdn")
      .and_return("stdout" => cmd_hostname, "exit" => 0)

    expect(Yast::Hostname.CurrentFQ).to eq cmd_hostname
  end

  it "reads /etc/hostname when hostname --fqdn fails" do
    allow(Yast::SCR)
      .to receive(:Execute)
      .with(path(".target.bash_output"), "hostname --fqdn")
      .and_return(nil)
    allow(Yast::SCR)
      .to receive(:Read)
      .with(path(".target.string"), "/etc/hostname")
      .and_return(etc_hostname)
    allow(Yast::FileUtils)
      .to receive(:Exists)
      .with("/etc/hostname")
      .and_return(true)

    expect(Yast::Hostname.CurrentFQ).to eq etc_hostname
  end
end
