#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "yast2/service_widget"

describe Yast2::ServiceWidget do
  let(:service) do
    double(
      "Yast2::SystemService",
      current_active?: true,
      start_mode: :on_boot,
      current_start_mode: :on_boot
    ).as_null_object
  end

  subject do
    described_class.new(
      service
    )
  end

  describe "#handle_input" do
    it "returns nil" do
      expect(subject.handle_input("")).to eq nil
    end
  end

  describe "#content" do
    it "returns Term" do
      expect(subject.content).to be_a(Yast::Term)
    end
  end

  describe "#store" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
    end

    it "resets service configuration" do
      expect(service).to receive(:reset)

      subject.store
    end

    it "calls action according to widget" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:service_widget_action), :CurrentItem).
        and_return(:service_widget_action_restart)

      expect(service).to receive(:restart)

      subject.store
    end

    it "sets start_mode according to widget" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:service_widget_autostart), :CurrentItem).
        and_return(:service_widget_autostart_manual)

      expect(service).to receive(:start_mode=).with(:manual)

      subject.store
    end
  end
end
