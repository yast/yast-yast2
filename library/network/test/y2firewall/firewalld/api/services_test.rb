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

describe Y2Firewall::Firewalld::Api::Services do
  subject(:api) { Y2Firewall::Firewalld::Api.new(mode: :offline) }

  describe "#create_service" do
    it "creates a new service definition with the given name" do
      expect(api).to receive(:modify_command).with("--new-service=test", permanent: false)

      subject.create_service("test")
    end

    it "returns whether the service was created successfully or not" do
      allow(api).to receive(:modify_command)
        .with("--new-service=test", permanent: false).and_return(true, false)
      expect(subject.create_service("test")).to eql(true)
      expect(subject.create_service("test")).to eql(false)
    end
  end

  describe "#remove_service" do
    it "deletes the given name service definition" do
      expect(api).to receive(:modify_command).with("--delete-service=test", permanent: false)

      subject.delete_service("test")
    end

    it "returns whether the service was deleted successfully or not" do
      allow(api).to receive(:modify_command)
        .with("--delete-service=test", permanent: false).and_return(true, false)
      expect(subject.delete_service("test")).to eql(true)
      expect(subject.delete_service("test")).to eql(false)
    end
  end

  describe "#services" do
    let(:defined_services) { "amanda-client amanda-k5-client amqp amqps apache2" }
    it "obtains the list of firewalld defined services" do
      allow(api).to receive(:string_command).with("--get-services").and_return(defined_services)

      expect(subject.services).to eql(defined_services.split(" "))
    end
  end

  describe "#service_short" do
    it "obtains the service short description of the given service" do
      allow(api).to receive(:string_command)
        .with("--service=test", "--get-short", permanent: api.permanent?)
        .and_return("Test short")

      expect(subject.service_short("test")).to eql("Test short")
    end
  end

  describe "#modify_service_short" do
    it "set the service short description of the given service" do
      expect(api).to receive(:modify_command)
        .with("--service=test", "--set-short=Modified", permanent: api.permanent?)

      subject.modify_service_short("test", "Modified")
    end
  end

  describe "#service_description" do
    let(:description) { "This is the long description of the test zone." }
    it "obtains the service long description of the given service" do
      allow(api).to receive(:string_command)
        .with("--service=test", "--get-description", permanent: api.permanent?)
        .and_return(description)

      expect(subject.service_description("test")).to eql(description)
    end
  end

  describe "#modify_service_short" do
    it "set the service long description of the given service" do
      expect(api).to receive(:modify_command)
        .with("--service=test", "--set-description=Modified Long", permanent: api.permanent?)

      subject.modify_service_description("test", "Modified Long")
    end
  end
end
