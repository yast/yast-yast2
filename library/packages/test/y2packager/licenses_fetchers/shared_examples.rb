#!/usr/bin/env rspec
# typed: false
# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "../../test_helper"

RSpec.shared_examples "a fetcher" do
  describe "#found?" do
    before do
      allow(subject).to receive(:content).with(anything).and_return(license_content)
    end

    context "when there is a default license content" do
      let(:license_content) { "Valid license content" }

      it "returns true" do
        expect(subject.found?).to eq(true)
      end
    end

    context "when there is not a default license content" do
      let(:license_content) { nil }

      it "returns false" do
        expect(subject.found?).to eq(false)
      end
    end

    context "when the default license content is empty" do
      let(:license_content) { "" }

      it "returns false" do
        expect(subject.found?).to eq(false)
      end
    end
  end
end
