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
require "yast2/system_service"

describe Yast2::ServiceWidget do
  # @param combobox [Yast::Term]
  # @param id [Symbol]
  def has_item?(combobox, id)
    items = combobox.params.last
    items.any? { |i| i.params[0].params == [id] }
  end

  let(:service) do
    instance_double(
      Yast2::SystemService,
      currently_active?:        true,
      start_mode:               :on_boot,
      current_start_mode:       :on_boot,
      start_modes:              [:on_boot, :on_demand, :manual],
      support_reload?:          true,
      support_start_on_boot?:   on_boot,
      support_start_on_demand?: on_demand,
      reset:                    nil,
      action:                   nil
    )
  end

  let(:on_demand) { true }
  let(:on_boot) { true }

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

    it "includes status label" do
      status_label = find_term(subject.content, :Label, :service_widget_status)

      expect(status_label).to_not be_nil
    end

    it "includes action selector" do
      action_selector = find_term(subject.content, :ComboBox, :service_widget_action)

      expect(action_selector).to_not be_nil
    end

    it "includes start mode selector" do
      autostart_selector = find_term(subject.content, :ComboBox, :service_widget_autostart)

      expect(autostart_selector).to_not be_nil
    end

    describe "start mode selector" do
      let(:autostart_selector) { find_term(subject.content, :ComboBox, :service_widget_autostart) }
      let(:items) { autostart_selector.params.last }

      before do
        allow(service).to receive(:support_start_on_demand?).and_return(on_demand)
      end

      context "when the service supports to be started on demand" do
        let(:on_demand) { true }

        it "includes a on demand option" do
          expect(has_item?(autostart_selector, :service_widget_autostart_on_demand)).to eq(true)
        end
      end

      context "when the service does not support to be started on demand" do
        let(:on_demand) { false }

        it "does not include an on demand option" do
          expect(has_item?(autostart_selector, :service_widget_autostart_on_demand)).to eq(false)
        end
      end

      context "when the service supports to be started on boot" do
        let(:on_boot) { true }

        it "includes a on boot option" do
          expect(has_item?(autostart_selector, :service_widget_autostart_on_boot)).to eq(true)
        end
      end

      context "when the service does not support to be started on boot" do
        let(:on_boot) { false }

        it "does not include an on boot option" do
          expect(has_item?(autostart_selector, :service_widget_autostart_on_boot)).to eq(false)
        end
      end

      it "includes an manual option" do
        expect(has_item?(autostart_selector, :service_widget_autostart_manual)).to eq(true)
      end
    end
  end

  describe "#refresh" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget).with(any_args)
    end

    it "updates the status" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:service_widget_status), :Value, anything)

      subject.refresh
    end

    it "updates available actions" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:service_widget_action), :Items, anything)

      subject.refresh
    end

    it "updates available options for start mode" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:service_widget_autostart), :Items, anything)

      subject.refresh
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
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:service_widget_action), :Value)
        .and_return(:service_widget_action_restart)

      expect(service).to receive(:restart)

      subject.store
    end

    it "sets start_mode according to widget" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:service_widget_autostart), :Value)
        .and_return(:service_widget_autostart_manual)

      expect(service).to receive(:start_mode=).with(:manual)

      subject.store
    end
  end
end
