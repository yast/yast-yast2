#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
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

require_relative "../test_helper"
require "cfa/sysctl_config"

describe CFA::SysctlConfig do
  subject(:config) { described_class.new }

  around do |example|
    change_scr_root(File.join(GENERAL_DATA_PATH, "sysctl-full"), &example)
  end

  describe "#load" do
    it "reads settings from files in all directories" do
      files = [
        "/boot/sysctl.conf-5.3.7-1-default",
        "/run/sysctl.d/05-syn_cookies.conf",
        "/etc/sysctl.d/30-yast.conf",
        "/etc/sysctl.d/50-overriden.conf",
        "/usr/local/lib/sysctl.d/10-lib.conf",
        "/usr/lib/sysctl.d/15-lib.conf",
        "/lib/sysctl.d/20-lib.conf",
        "/etc/sysctl.conf"
      ]
      files.each do |name|
        expect(CFA::Sysctl).to receive(:new).with(file_path: name).and_call_original
      end

      config.load
    end

    it "settings for the given kernel are read from /boot"

    context "when two files have the same name" do
      it "only reads the first one" do
        expect(CFA::Sysctl).to_not receive(:new).with(file_path: "/lib/sysctl.d/50-overriden.conf")
        allow(CFA::Sysctl).to receive(:new).and_call_original
        config.load
      end
    end
  end

  xdescribe "#files" do
    let(:execute_object) { Yast::Execute.new }

    context "when a specific kernel flavor configuration is found" do
      before do
        allow(Yast::Execute).to receive(:locally).and_return(execute_object)
        allow(execute_object).to receive(:stdout).with("/usr/bin/uname", "-r").and_return("5.3.7-1-default")
      end

      it "includes it in the first position" do
        expect(config.files[0].file_path).to eq("/boot/sysctl.conf-5.3.7-1-default")
      end

      it "does not include other kernel configurations" do
        expect(config.files.map(&:file_path)).to_not include(/5.3.6-1-default/)
      end

      it "includes the other configuration files lexicographically ordered" do
        expect(config.files[1..-1].map(&:file_path)).to eq([
          "/etc/sysctl.d/30-yast.conf",
          "/run/sysctl.d/syn_cookies.conf",
          "/etc/sysctl.conf"
        ])
      end
    end

    context "when no specific kernel configurations are found" do
      before do
        allow(Yast::Execute).to receive(:locally).and_return(execute_object)
        allow(execute_object).to receive(:stdout).with("/usr/bin/uname", "-r").and_return("")
      end

      it "does not include /boot" do
        expect(config.files.map(&:file_path)).to_not include(/\/boot/)
      end

      it "includes configuration files lexicographically ordered" do
        expect(config.files.map(&:file_path)).to eq([
          "/etc/sysctl.d/30-yast.conf",
          "/run/sysctl.d/syn_cookies.conf",
          "/etc/sysctl.conf"
        ])
      end
    end

    it "does not include ignored configuration files (same name, less precedense location)" do
      expect(config.files.map(&:file_path)).to_not include("/etc/system.d/sync_cookies.conf")
    end
  end

  describe "#forward_ipv4" do
    before do
      config.load
    end

    it "returns the forward_ipv4 value with highest precedence" do
      expect(config.forward_ipv4).to eq(true)
    end

    context "when the value is not present" do
      it "returns the default from the main file" do
        expect(config.forward_ipv6).to eq(false)
      end
    end
  end

  describe "#forward_ipv4=" do
    before do
      config.load
    end

    it "changes the value" do
      expect { config.forward_ipv4 = false }.to change { config.forward_ipv4 }.from(true).to(false)
    end
  end

  describe "#conflict?" do
    context "when YaST configuration file is empty" do
      it "returns false" do
        expect(config.conflict?).to eq(false)
      end
    end

    xcontext "when YaST configuration file is present" do
      before do
        config.load
        file.kernel_sysrq = sysrq
      end

      let(:file) { config.higher_precedence_files.last }
      let(:sysrq) { "0" }

      context "and no specific attributes are given" do
        xit "checks all known attributes" do
          expect(file).to receive(:present?).exactly(CFA::Sysctl.known_attributes.count).times
          config.conflict?
        end
      end

      context "when some main file value is overriden" do
        let(:sysrq) { "0" }

        it "returns true" do
          expect(config.conflict?).to eq(true)
        end
      end

      context "when no value is overriden" do
        let(:sysrq) { nil }

        it "returns false" do
          expect(config.conflict?).to eq(false)
        end
      end
    end
  end
end
