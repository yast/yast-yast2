#!/usr/bin/env rspec
# ------------------------------------------------------------------------------
# Copyright (c) 2022 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "../test_helper"

require "y2packager/new_repository_setup"

describe Y2Packager::NewRepositorySetup do
  # create anonymous subclass to have a fresh singleton instance for each test
  subject { Class.new(Y2Packager::NewRepositorySetup).instance }

  describe "#add_repository" do
    it "stores the repository into the list" do
      subject.add_repository("test_repo")
      expect(subject.repositories).to include("test_repo")
    end
  end

  describe "#add_service" do
    it "stores the service into the list" do
      subject.add_service("test_service")
      expect(subject.services).to include("test_service")
    end
  end
end
