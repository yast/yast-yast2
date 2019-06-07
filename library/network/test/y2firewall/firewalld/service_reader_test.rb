#!/usr/bin/env rspec
# typed: false
# encoding: utf-8
#
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

require_relative "../../test_helper"
require "y2firewall/firewalld"
require "y2firewall/firewalld/service_reader"

describe Y2Firewall::Firewalld::ServiceReader do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:api) { instance_double("Y2Firewall::Firewalld::Api", state: "not_running") }

  before do
    allow(firewalld).to receive(:api).and_return(api)
    `echo true`
  end

  describe "#read" do
    let(:service_info) do
      [
        "radius",
        "  summary: My service",
        "  description: This is my service description",
        "  ports: 137/tcp 137/udp",
        "  protocols: igmp",
        "  source-ports: ",
        "  modules: nf_conntrack_netbios_ns",
        "  destination: "
      ]
    end

    context "when the service is not present" do
      let(:service_name) { "not_present" }
      before do
        allow(api).to receive(:info_service).with(service_name)
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(101)
      end

      it "raises a NotFound exception" do
        expect { subject.read(service_name) }.to raise_error(Y2Firewall::Firewalld::Service::NotFound)
      end
    end

    context "when the service configuration exists" do
      let(:service_name) { "radius" }
      before do
        allow(api).to receive(:info_service).with(service_name)
          .and_return(service_info)
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(1)
      end

      it "returns the service with the parsed configuration" do
        service = subject.read(service_name)
        expect(service.short).to eq("My service")
        expect(service.ports).to eq(["137/tcp", "137/udp"])
        expect(service.protocols).to eq(["igmp"])
      end
    end
  end
end
