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

describe Yast2::Systemd::UnitProperties do
  include SystemdServiceStubs

  describe "#static?" do
    subject(:properties) { described_class.new(service, nil) }
    let(:service) { Yast2::Systemd::Service.build(service_name) }

    before do
      stub_services(service: service_name)
    end

    context "when service is static" do
      let(:service_name) { "tftp" }

      it "returns true" do
        expect(properties.static?).to eq(true)
      end
    end

    context "when service is not static" do
      let(:service_name) { "sshd" }

      it "returns false" do
        expect(properties.static?).to eq(false)
      end
    end
  end
end
