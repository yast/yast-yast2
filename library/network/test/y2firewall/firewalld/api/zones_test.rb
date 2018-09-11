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

require_relative "../../../test_helper"
require "y2firewall/firewalld/api"

describe Y2Firewall::Firewalld::Api::Zones do
  subject(:api) { Y2Firewall::Firewalld::Api.new(mode: :offline) }

  describe "#zones" do
    let(:known_zones) { "dmz drop external home internal public trusted work" }
    it "obtains the list of firewalld defined zones" do
      allow(api).to receive(:string_command).with("--get-zones").and_return(known_zones)

      expect(subject.zones).to eql(known_zones.split(" "))
    end
  end

  describe "#short" do
    it "obtains the zone short description" do
      allow(api).to receive(:string_command)
        .with("--zone=test", "--get-short", permanent: api.permanent?)
        .and_return("Test short")

      expect(subject.short("test")).to eql("Test short")
    end
  end

  describe "#modify_short" do
    it "modifies the zone short description" do
      expect(api).to receive(:modify_command)
        .with("--zone=test", "--set-short=Modified", permanent: api.permanent?)

      subject.modify_short("test", "Modified")
    end
  end

  describe "#description" do
    let(:description) { "This is the long description of the test zone." }
    it "obtains the zone long description" do
      allow(api).to receive(:string_command)
        .with("--zone=test", "--get-description", permanent: api.permanent?)
        .and_return(description)

      expect(subject.description("test")).to eql(description)
    end
  end

  describe "#modify_description" do
    it "modifies the zone long description" do
      expect(api).to receive(:modify_command)
        .with("--zone=test", "--set-description=Modified Long", permanent: api.permanent?)

      subject.modify_description("test", "Modified Long")
    end
  end

  describe "#target" do
    it "obtains the zone target" do
      allow(api).to receive(:string_command)
        .with("--zone=test", "--get-target", permanent: !api.offline?)
        .and_return("ACCEPT")

      expect(subject.target("test")).to eql("ACCEPT")
    end
  end

  describe "#modify_target" do
    it "modifies the zone target" do
      expect(api).to receive(:modify_command)
        .with("--zone=test", "--set-target=drop", permanent: !api.offline?)

      subject.modify_target("test", "drop")
    end
  end
  describe "#masquerade_enabled?" do
    it "returns false if the zone has masquerade disabled" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-masquerade", permanent: api.permanent?)
        .and_return(false)
      expect(subject.masquerade_enabled?("public")).to eql(false)
    end

    it "returns true if the zone has masquerade enabled" do
      allow(api).to receive(:query_command)
        .with("--zone=external", "--query-masquerade", permanent: api.permanent?)
        .and_return(true)

      expect(subject.masquerade_enabled?("external")).to eql(true)
    end
  end

  describe "#list_ports" do
    it "returns the list of ports opened by the zone" do
      allow(api).to receive(:string_command)
        .with("--zone=test", "--list-ports", permanent: api.permanent?)
        .and_return("80/tcp 443/tcp")

      expect(api.list_ports("test")).to eql(["80/tcp", "443/tcp"])
    end
  end

  describe "#list_protocols" do
    it "returns the list of protocols opened by the zone" do
      allow(api).to receive(:string_command)
        .with("--zone=test", "--list-protocols", permanent: api.permanent?)
        .and_return("egp gre")

      expect(api.list_protocols("test")).to eql(["egp", "gre"])
    end
  end

  describe "#remove_port" do
    it "removes the given port from the zone configured ports" do
      expect(api).to receive(:modify_command)
        .with("--zone=test", "--remove-port=80/tcp", permanent: api.permanent?)

      api.remove_port("test", "80/tcp")
    end
  end

  describe "#add_port" do
    it "adds the given port to the zone configured ports" do
      expect(api).to receive(:modify_command)
        .with("--zone=test", "--add-port=80/tcp", permanent: api.permanent?)

      api.add_port("test", "80/tcp")
    end
  end

  describe "#port_enabled?" do
    it "returns false if the port is not allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-port=80/tcp", permanent: !api.offline?)
        .and_return(false)
      expect(subject.port_enabled?("public", "80/tcp")).to eql(false)
    end

    it "returns true if the port is allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-port=22/tcp", permanent: !api.offline?)
        .and_return(true)
      expect(subject.port_enabled?("public", "22/tcp")).to eql(true)
    end
  end

  describe "#port_enabled?" do
    it "returns false if the port is not allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-port=80/tcp", permanent: api.permanent?)
        .and_return(false)
      expect(subject.port_enabled?("public", "80/tcp")).to eql(false)
    end

    it "returns true if the port is allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-port=22/tcp", permanent: api.permanent?)
        .and_return(true)
      expect(subject.port_enabled?("public", "22/tcp")).to eql(true)
    end
  end

  describe "#protocol_enabled?" do
    it "returns false if the protocol is not allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-protocol=igmp", permanent: api.permanent?)
        .and_return(false)
      expect(subject.protocol_enabled?("public", "igmp")).to eql(false)
    end

    it "returns true if the protocol is allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-protocol=gre", permanent: api.permanent?)
        .and_return(true)
      expect(subject.protocol_enabled?("public", "gre")).to eql(true)
    end
  end

  describe "#service_enabled?" do
    it "returns false if the service is not allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-service=samba", permanent: api.permanent?)
        .and_return(false)
      expect(subject.service_enabled?("public", "samba")).to eql(false)
    end

    it "returns true if the service is allowed by the zone" do
      allow(api).to receive(:query_command)
        .with("--zone=public", "--query-service=http", permanent: api.permanent?)
        .and_return(true)
      expect(subject.service_enabled?("public", "http")).to eql(true)
    end
  end
end
