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

require "yast2/compound_service"

describe Yast2::CompoundService do
  def service(*args)
    args[0] ||= {}
    args[0][:"is_a?"] = true
    args[0][:errors] = {}
    double("Yast2::SystemService", *args).as_null_object
  end

  let(:service1) { service }
  let(:service2) { service }

  subject do
    described_class.new(
      service1,
      service2
    )
  end

  describe ".new" do
    it "raises ArgumentError if non service is passed" do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#save" do
    it "delegates save to all services it handles" do
      expect(service1).to receive(:save)
      expect(service2).to receive(:save)

      subject.save
    end

    it "returns false if any service save failed" do
      allow(service2).to receive(:errors).and_return(start_mode: :on_boot)

      expect(subject.save).to eq false
    end
  end

  describe "#errors" do
    it "returns merge of all underlaying services errors" do
      allow(service1).to receive(:errors).and_return(action: :restart)
      allow(service2).to receive(:errors).and_return(start_mode: :on_boot)

      expect(subject.errors).to eq action: :restart, start_mode: :on_boot
    end
  end

  describe "#current_active?" do
    context "all services are active" do
      subject { described_class.new(service(current_active?: true), service(current_active?: true)) }

      it "returns true" do
        expect(subject.current_active?).to eq true
      end
    end

    context "all services are inactive" do
      subject { described_class.new(service(current_active?: false), service(current_active?: false)) }

      it "returns false" do
        expect(subject.current_active?).to eq false
      end
    end

    context "some services are active and some inactive" do
      subject { described_class.new(service(current_active?: false), service(current_active?: true)) }

      it "returns :inconsistent" do
        expect(subject.current_active?).to eq :inconsistent
      end
    end
  end

  describe "#support_reload?" do
    subject { described_class.new(service(support_reload?: true), service(support_reload?: false)) }

    it "returns true if any service support reload" do
      expect(subject.support_reload?).to eq true
    end
  end

  describe "#start_modes" do
    subject do
      described_class.new(
        service(start_modes: [:on_boot, :manual]),
        service(start_modes: [:on_boot, :on_demand, :manual])
      )
    end

    it "returns all start_modes that any of service has" do
      expect(subject.start_modes).to contain_exactly :on_boot, :on_demand, :manual
    end
  end

  describe "#keywords" do
    subject do
      described_class.new(
        service(keywords: ["unita.service"]),
        service(keywords: ["unitb.service", "unitb.socket"])
      )
    end

    it "returns all keywords that any of service has" do
      expect(subject.keywords).to contain_exactly "unita.service", "unitb.socket", "unitb.service"
    end
  end

  describe "#action" do
    it "returns action specified on given services" do
      subject = described_class.new(
        service(action: :reboot),
        service(action: :reboot)
      )

      expect(subject.action).to eq :reboot
    end
  end

  describe "#current_start_mode" do
    context "all services start on boot currently" do
      subject do
        described_class.new(
          service(current_start_mode: :on_boot),
          service(current_start_mode: :on_boot)
        )
      end

      it "returns :on_boot" do
        expect(subject.current_start_mode).to eq :on_boot
      end
    end

    context "all services don't start automatic" do
      subject do
        described_class.new(
          service(current_start_mode: :manual),
          service(current_start_mode: :manual)
        )
      end

      it "returns :manual" do
        expect(subject.current_start_mode).to eq :manual
      end
    end

    context "services which supports it start on demand and rest start on boot" do
      subject do
        described_class.new(
          service(current_start_mode: :on_demand, support_start_on_demand?: true),
          service(current_start_mode: :on_boot, support_start_on_demand?: false)
        )
      end

      it "returns :on_demand" do
        expect(subject.current_start_mode).to eq :on_demand
      end
    end

    context "mixture of automatic start configuration" do
      subject do
        described_class.new(
          service(current_start_mode: :on_boot),
          service(current_start_mode: :manual)
        )
      end

      it "returns :inconsistent" do
        expect(subject.current_start_mode).to eq :inconsistent
      end
    end
  end

  describe "#start_mode" do
    context "all services are set to start on boot" do
      subject do
        described_class.new(
          service(start_mode: :on_boot),
          service(start_mode: :on_boot)
        )
      end

      it "returns :on_boot" do
        expect(subject.start_mode).to eq :on_boot
      end
    end

    context "all services are set to not start automatic" do
      subject do
        described_class.new(
          service(start_mode: :manual),
          service(start_mode: :manual)
        )
      end

      it "returns :manual" do
        expect(subject.start_mode).to eq :manual
      end
    end

    context "services which supports it are started on demand and rest start on boot" do
      subject do
        described_class.new(
          service(start_mode: :on_demand, support_start_on_demand?: true),
          service(start_mode: :on_boot, support_start_on_demand?: false)
        )
      end

      it "returns :on_demand" do
        expect(subject.start_mode).to eq :on_demand
      end
    end

    context "mixture of automatic start configuration" do
      subject do
        described_class.new(
          service(start_mode: :on_boot),
          service(start_mode: :manual)
        )
      end

      it "returns :inconsistent" do
        expect(subject.start_mode).to eq :inconsistent
      end
    end
  end

  describe "#start_mode=" do
    context "parameter is :on_boot" do
      it "sets all services to start on boot" do
        expect(service1).to receive(:start_mode=).with(:on_boot)
        expect(service2).to receive(:start_mode=).with(:on_boot)

        subject.start_mode = :on_boot
      end
    end

    context "parameter is :manual" do
      it "sets all services to not start automatic" do
        expect(service1).to receive(:start_mode=).with(:manual)
        expect(service2).to receive(:start_mode=).with(:manual)

        subject.start_mode = :manual
      end
    end

    context "parameter is :on_demand" do
      let(:service1) { service(support_start_on_demand?: true) }
      let(:service2) { service(support_start_on_demand?: false) }

      it "sets services that support it start on demand and rest on boot" do
        expect(service1).to receive(:start_mode=).with(:on_demand)
        expect(service2).to receive(:start_mode=).with(:on_boot)

        subject.start_mode = :on_demand
      end
    end

    context "parameter is :inconsistent" do
      it "resets automatic start configuration on all services" do
        expect(subject).to receive(:reset).with(exclude: [:action])

        subject.start_mode = :inconsistent
      end
    end
  end

  describe "#support_start_on_demand?" do
    subject { described_class.new(service(support_start_on_demand?: true), service(support_start_on_demand?: false)) }

    it "returns true if any service supports starting on demand" do
      expect(subject.support_start_on_demand?).to eq true
    end
  end

  describe "#reset" do
    it "calls reset on all services" do
      expect(service1).to receive(:reset)
      expect(service2).to receive(:reset)

      subject.reset
    end

    context "action is excluded" do
      let(:service1) { service(action: :start) }
      it "redoes previous action on service" do
        expect(service1).to receive(:start)

        subject.reset(exclude: [:action])
      end
    end

    context "action is not excluded" do
      let(:service1) { service(action: :start) }
      it "does not redo previous action on service" do
        expect(service1).to_not receive(:start)

        subject.reset(exclude: [])
      end
    end

    context "start_mode is excluded" do
      let(:service1) { service(start_mode: :on_boot) }
      it "set again start mode" do
        expect(subject).to receive(:start_mode).and_return(:on_boot)
        expect(service1).to receive(:start_mode=).with(:on_boot)

        subject.reset(exclude: [:start_mode])
      end
    end

    context "start_mode is not excluded" do
      let(:service1) { service(start_mode: :on_boot) }
      it "does not set start mode" do
        expect(subject).to receive(:start_mode).and_return(:on_boot)
        expect(service1).to_not receive(:start_mode=)

        subject.reset(exclude: [])
      end
    end
  end

  describe "#start" do
    it "calls start for each service" do
      expect(service1).to receive(:start)
      expect(service2).to receive(:start)

      subject.start
    end
  end

  describe "#stop" do
    it "calls stop for each service" do
      expect(service1).to receive(:stop)
      expect(service2).to receive(:stop)

      subject.stop
    end
  end

  describe "#restart" do
    it "calls restart for each service" do
      expect(service1).to receive(:restart)
      expect(service2).to receive(:restart)

      subject.restart
    end
  end

  describe "#reload" do
    it "calls reload for each service" do
      expect(service1).to receive(:reload)
      expect(service2).to receive(:reload)

      subject.reload
    end
  end
end
