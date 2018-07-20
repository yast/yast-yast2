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
    double("Yast2::SystemService", *args).as_null_object
  end

  describe ".new" do
    it "raises ArgumentError if non service is passed" do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#save" do
    it "delegates save to all services it handles" do
      service1 = service
      service2 = service
      expect(service1).to receive(:save)
      expect(service2).to receive(:save)

      service = described_class.new(service1, service2)
      service.save
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
end
