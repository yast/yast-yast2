#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require "y2firewall/firewalld/api"

describe Y2Firewall::Firewalld::Api do
  subject(:api) { described_class.new(mode: :offline) }

  describe ".initialize" do
    let(:running?) { false }
    before do
      allow_any_instance_of(described_class).to receive(:running?).and_return(running?)
    end

    context "when no option is given" do
      subject(:api) { described_class.new }

      context "and the firewall is running" do
        let(:running?) { true }

        it "sets the API mode as :running" do
          expect(api.offline?).to eq(false)
        end

        it "sets the configuration to be read and written permanently" do
          expect(api.permanent?).to eq(true)
        end
      end

      context "and the firewall is not running" do
        let(:running?) { false }

        it "sets the API mode as :offline" do
          expect(api.offline?).to eq(true)
        end
      end
    end

    context "when the API mode is given" do
      it "sets the mode" do
        expect(described_class.new(mode: :offline).offline?).to eq(true)
        expect(described_class.new(mode: :running).offline?).to eq(false)
      end
    end
  end

  describe "#offline?" do
    subject(:api) { described_class.new(mode: :offline) }

    it "returns true if the api is in :offline mode " do
      expect(api.offline?).to eql(true)
    end

    it "returns false otherwise" do
      api.instance_variable_set("@mode", ":running")
      expect(api.offline?).to eql(false)
    end
  end

  describe "#permanent?" do
    subject(:api) { described_class.new(mode: :offline) }

    context "when the API is in :offline mode" do
      it "returns false" do
        expect(api.permanent?).to eql(false)
      end
    end

    context "when the API is in :running mode" do
      it "returns true if the configuration should be written permanently" do
        expect(described_class.new(mode: :running, permanent: true).permanent?).to eql(true)
      end

      it "returns false if the configuration should be written only in runtime" do
        expect(described_class.new(mode: :running, permanent: false).permanent?).to eql(false)
      end
    end
  end

  describe "#running?" do
    let(:package) { Y2Firewall::Firewalld::Api::PACKAGE }
    let(:state) { "running" }

    before do
      allow(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::PackageSystem).to receive(:Installed).with(package).and_return(true)
      allow(api).to receive(:state).and_return(state)
    end

    it "returns false during the installation first stage" do
      allow(Yast::Stage).to receive(:initial).and_return(true)

      expect(api.running?).to eql(false)
    end

    it "returns false if the firewalld package is not installed" do
      allow(Yast::PackageSystem).to receive(:Installed).with(package).and_return(false)

      expect(api.running?).to eql(false)
    end

    it "returns whether the firewalld state is 'running' or not" do
      allow(api).to receive(:state).and_return("not_running", "running")
      expect(api.running?).to eql(false)
      expect(api.running?).to eql(true)
    end
  end

  describe "#enable!" do
    context "when the firewall is not running" do
      subject(:api) { described_class.new(mode: :offline) }

      it "enables the firewalld service through the firewalld offline cmd API" do
        expect(api).to receive(:run_command).with("--enable")

        api.enable!
      end
    end

    context "when the firewall is running" do
      subject(:api) { described_class.new(mode: :running) }

      it "enables the firewalld service through the Yast::Service module " do
        expect(Yast::Service).to receive(:Enable).with("firewalld")

        api.enable!
      end
    end
  end

  describe "#state" do
    it "returns 'running' when the firewall is running" do
      allow(Yast::Execute).to receive(:on_target)
        .with("firewall-cmd", "--state", allowed_exitstatus: [0, 252]).and_return(0)

      expect(api.state).to eql("running")
    end

    it "returns 'not running' when the firewall is not running" do
      allow(Yast::Execute).to receive(:on_target)
        .with("firewall-cmd", "--state", allowed_exitstatus: [0, 252]).and_return(252)

      expect(api.state).to eql("not running")
    end

    it "returns 'unknown' in case of an unexpected state" do
      allow(Yast::Execute).to receive(:on_target)
        .with("firewall-cmd", "--state", allowed_exitstatus: [0, 252]).and_return(24)

      expect(api.state).to eql("unknown")
    end
  end

  describe "#log_denied_packets" do
    before do
      allow(api).to receive(:string_command).with("--get-log-denied").and_return("all")
    end

    it "returns the kind of packets to be logged" do
      expect(api.log_denied_packets).to eql("all")
    end
  end

  describe "#log_denied_packets=" do
    it "modifies the kind of packets to be logged" do
      expect(api).to receive(:string_command).with("--set-log-denied=broadcast", permanent: false)
      api.log_denied_packets = "broadcast"
    end
  end

  describe "#default_zone" do
    before do
      allow(api).to receive(:string_command).with("--get-default-zone").and_return("drop")
    end

    it "returns the current firewalld default zone" do
      expect(api.default_zone).to eql("drop")
    end
  end

  describe "#default_zone=" do
    it "modifies the firewalld default zone" do
      expect(api).to receive(:string_command).with("--set-default-zone=external", permanent: false)
      api.default_zone = "external"
    end
  end

  describe "#reload" do
    context "when the firewall is not running" do
      it "returns true" do
        expect(api.reload).to eql(true)
      end
    end

    context "when the firewall is running" do
      subject(:api) { described_class.new(mode: :running) }

      it "reloads the firewalld configuration" do
        expect(api).to receive(:modify_command).with("--reload")
        api.reload
      end

      it "returns whether the configuration was reloaded successfully" do
        allow(api).to receive(:modify_command).with("--reload").and_return(true)

        expect(api.reload).to eql(true)
      end
    end
  end

  describe "#complete_reload" do
    context "when the firewall is not running" do
      it "returns true" do
        expect(api.complete_reload).to eql(true)
      end
    end

    context "when the firewall is running" do
      subject(:api) { described_class.new(mode: :running) }

      it "reloads the firewalld configuration" do
        expect(api).to receive(:modify_command).with("--complete-reload")
        api.complete_reload
      end
    end
  end
end
