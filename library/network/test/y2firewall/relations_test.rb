#!/usr/bin/env rspec
# encoding: utf-8

#
# Copyright (c) 2018 SUSE LLC
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
require "y2firewall/firewalld"

describe Y2Firewall::Firewalld::Relations do
  class Dummy
    extend Y2Firewall::Firewalld::Relations
    attr_accessor :api

    has_attributes :description
    has_many :dummies

    enable_modifications_cache
  end

  describe ".enable_modifications_cache" do
    subject { Dummy.new }

    it "defines the 'modified' method" do
      expect(subject.modified).to be_an(Array)
    end

    it "defines the 'modified!' method" do
      expect(subject.modified?).to eq(false)
      subject.modified! :name
      expect(subject.modified?).to eq(true)
    end

    it "defines the 'untouched!' method" do
      subject.untouched!
      expect(subject.modified?).to eq(false)
    end

    it "defines the 'modified?' method" do
      subject.modified! :name
      expect(subject.modified?(:name)).to eq(true)
    end
  end

  describe ".has_attributes" do
    subject { Dummy.new }

    let(:api) do
      instance_double("Y2Firewall::Firewalld::API",
        description: "dummy text", dummies: ["john", "doe"])
    end

    before { allow(subject).to receive(:api).and_return(api) }

    it "defines a getter and a setter for each given attribute" do
      expect(subject.respond_to?("description")).to eq(true)
      expect(subject.respond_to?("description=")).to eq(true)
    end

    it "defines the 'attributes' method" do
      expect(subject.attributes).to eq([:description])
    end

    it "defines the \"current_'attribute'\" method" do
      subject.current_description
    end

    it "defines the 'read_attributes' method" do
      subject.read_attributes
      expect(subject.description).to eq("dummy text")
    end

    it "defines the 'apply_attributes_changes!' method" do
      subject.description = "modified dummy text"
      expect(api).to receive(:public_send).with("modify_description", "modified dummy text")

      subject.apply_attributes_changes!
    end
  end
end
