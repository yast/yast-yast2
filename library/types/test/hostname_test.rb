#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

describe "Hostname#CurrentFQ" do
  it "reads /etc/hostname when hostname --fqdn fails" do
    TEST_HOSTNAME = "host.suse.cz"

    Yast.import "Hostname"
    Yast.import "FileUtils"

    allow(Yast::SCR)
      .to receive(:Execute)
      .with(path(".target.bash_output"), "hostname --fqdn")
      .and_return(nil)
    allow(Yast::SCR)
      .to receive(:Read)
      .with(path(".target.string"), "/etc/hostname")
      .and_return(TEST_HOSTNAME)
    allow(Yast::FileUtils)
      .to receive(:Exists)
      .with("/etc/hostname")
      .and_return(true)

    expect(Yast::Hostname.CurrentFQ).to eq TEST_HOSTNAME
  end
end
