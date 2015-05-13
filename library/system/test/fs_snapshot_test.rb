#!/usr/bin/env rspec

require_relative "test_helper"
require_relative "../src/lib/yast2/fs_snapshot"

describe Yast2::FsSnapshot do
  describe ".create" do
    context "when snapshot creation fails" do
      it "should returns nil"
    end

    context "when snapshot creation is successful" do
      it "should return the just create snapshot"
    end
  end

  describe ".find" do
    context "when a snapshot with that number exists" do
      it "should return the snapshot"
    end

    context "when a snapshot with that number does not exists" do
      it "should return nil"
    end
  end

  describe ".all" do
    context "given some snapshots exist" do
      it "should return the snapshots ordered by timestamp"
    end

    context "given no snapshots exist" do
      it "should return an empty array"
    end
  end

  describe "#destroy" do
    it "should destroy the snapshot"
  end
end
