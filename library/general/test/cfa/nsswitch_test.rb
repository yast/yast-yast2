# Copyright (c) [2020] SUSE LLC
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
require "cfa/nsswitch"
require "cfa/memory_file"

describe CFA::Nsswitch do
  subject { described_class.new(file_handler: file_handler) }

  let(:file_handler) { Yast::TargetFile }
  let(:scenario) { "custom" }

  around do |example|
    change_scr_root(File.join(GENERAL_DATA_PATH, "nsswitch.conf", scenario), &example)
  end

  describe "#load" do
    context "when /etc/nsswitch.conf exists" do
      before do
        allow(file_handler).to receive(:read).and_call_original
      end

      it "does not read /usr/etc/nsswitch.conf file" do
        expect(file_handler).to_not receive(:read)
          .with("/usr/etc/nsswitch.conf")
        subject.load
      end

      it "reads /etc/nsswitch.conf file" do
        expect(file_handler).to receive(:read)
          .with("/etc/nsswitch.conf")
          .and_call_original
        subject.load
      end
    end

    context "when /etc/nsswitch.conf does not exist" do
      let(:scenario) { "vendor" }

      it "reads vendor files" do
        expect(file_handler).to receive(:read)
          .with("/usr/etc/nsswitch.conf")
          .and_call_original
        subject.load
      end
    end
  end

  describe "#save" do
    before { subject.load }

    let(:file_handler) { CFA::MemoryFile.new(file_content) }
    let(:file_content) do
      <<~CONTENT
        # An custom Name Service Switch config file.
        #
        # Valid databases are: aliases, ethers, group, gshadow, hosts,
        # initgroups, netgroup, networks, passwd, protocols, publickey,
        # rpc, services, and shadow.

        passwd: compat
        group:  compat
        shadow: compat

        hosts:  db files
      CONTENT
    end

    context "when it has changed" do
      before do
        subject.update_entry("hosts", ["dns", "nis"])
      end

      it "writes requested changes" do
        subject.save

        expect(file_handler.content).to match(/hosts:\s+dns nis/)
        expect(file_handler.content).to_not match(/hosts:  db files/)
      end

      it "writes to /etc/nsswitch.conf file" do
        expect(file_handler).to receive(:write)
          .with("/etc/nsswitch.conf", anything)
        subject.save
      end

      it "does not write to /usr/etc/nsswitch.conf file" do
        expect(file_handler).to_not receive(:write)
          .with("/user/etc/nsswitch.conf", anything)
        subject.save
      end
    end

    context "when it has not changed" do
      it "does nothing" do
        expect(file_handler).to_not receive(:write)

        subject.save

        expect(file_handler.content).to eq(file_content)
      end
    end
  end

  describe "#modified?" do
    before  { subject.load }

    context "when it has changed" do
      before do
        subject.update_entry("hosts", ["dns", "nis"])
      end

      it "returns true" do
        expect(subject.modified?).to eq(true)
      end
    end

    context "when it has not changed" do
      it "returns false" do
        expect(subject.modified?).to eq(false)
      end
    end
  end

  describe "#entries" do
    before { subject.load }

    it "returns the database names currently present in the configuration" do
      expect(subject.entries).to eq(["passwd", "group", "shadow", "hosts"])
    end
  end

  describe "#services_for" do
    before { subject.load }

    context "when given an available database entry" do
      it "returns the service specifications for given database name" do
        expect(subject.services_for("hosts")).to eq(["db", "files"])
      end
    end

    context "when given a not available database entry" do
      it "returns nil" do
        expect(subject.services_for("foo")).to be_nil
      end
    end
  end

  describe "#update_entry" do
    before { subject.load }

    context "when given an available database entry" do
      it "changes database entry to use given services" do
        old_services = subject.services_for("hosts")
        new_services = ["other", "services"]
        subject.update_entry("hosts", new_services)
        updated_services = subject.services_for("hosts")

        expect(updated_services).to eq(new_services)
        expect(updated_services).to_not eq(old_services)
      end
    end

    context "when given a not available database entry" do
      it "creates the database entry with given services" do
        expect(subject.entries).to_not include("foo")

        subject.update_entry("foo", ["bar"])

        expect(subject.entries).to include("foo")
        expect(subject.services_for("foo")).to eq(["bar"])
      end
    end
  end

  describe "#delete_entry" do
    before { subject.load }

    it "deletes given entry" do
      expect(subject.services_for("hosts")).to_not be_nil

      subject.delete_entry("hosts")

      expect(subject.services_for("hosts")).to be_nil
    end
  end
end
