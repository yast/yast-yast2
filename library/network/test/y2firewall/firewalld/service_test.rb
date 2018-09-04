#!/usr/bin/env rspec
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
require "y2firewall/firewalld/service"

describe Y2Firewall::Firewalld::Service do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:api) { instance_double("Y2Firewall::Firewalld::Api") }
  let(:installed?) { true }

  before do
    allow(firewalld).to receive(:find_service).with("service")
    allow(firewalld).to receive(:api).and_return(api)
    allow(firewalld).to receive(:installed?).and_return(installed?)
  end

  describe ".modify_ports" do
    subject { described_class }

    let(:service) { described_class.new(name: "service") }

    context "when firewalld is not installed" do
      let(:installed?) { false }

      it "returns false" do
        expect(subject.modify_ports(name: "service", tcp_ports: ["80", "8080"])).to eq(false)
      end
    end

    context "when firewalld is installed" do
      before do
        allow(service).to receive(:ports=)
        allow(service).to receive(:apply_changes!)
        allow(firewalld).to receive(:find_service).with("service").and_return(service)
      end

      it "looks for the the service with the name given if exists" do
        expect(firewalld).to receive(:find_service).with("service").and_return(service)

        subject.modify_ports(name: "service", tcp_ports: ["80"])
      end

      it "modifies the service tcp and udp ports" do
        expect(service).to receive(:ports=).with(["80/tcp", "8080/tcp", "53/udp"])
        expect(service).to receive(:apply_changes!)

        subject.modify_ports(name: "service", tcp_ports: ["80", "8080"], udp_ports: ["53"])
      end
    end
  end
end
