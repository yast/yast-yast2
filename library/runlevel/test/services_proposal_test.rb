#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

module Yast
  Yast.import "ServicesProposal"

  describe ServicesProposal do
    before(:each) do
      ServicesProposal.reset
    end

    describe "#enable_service" do
      it "marks service as enabled" do
        ServicesProposal.enable_service("s1")
        expect(ServicesProposal.enabled_services).to eq(["s1"])

        ServicesProposal.enable_service("s2")
        expect(ServicesProposal.enabled_services.sort).to eq(["s1", "s2"].sort)

        ServicesProposal.enable_service("s5")
        expect(ServicesProposal.enabled_services).to eq(["s1", "s2", "s5"].sort)
      end
    end

    describe "#disable_service" do
      it "marks service as disabled" do
        ServicesProposal.disable_service("s7")
        expect(ServicesProposal.disabled_services).to eq(["s7"])

        ServicesProposal.disable_service("s8")
        expect(ServicesProposal.disabled_services.sort).to eq(["s7", "s8"].sort)

        ServicesProposal.disable_service("s9")
        expect(ServicesProposal.disabled_services.sort).to eq(["s7", "s8", "s9"].sort)
      end
    end

    describe "#enabled_services" do
      it "returns all services marked as enabled" do
        disable_services = ["1", "d", "e", "f"]
        disable_services.each do |service|
          ServicesProposal.disable_service(service)
        end

        enable_services = ["1", "a", "b", "c"]
        enable_services.each do |service|
          ServicesProposal.enable_service(service)
        end

        expect(ServicesProposal.enabled_services.sort).to eq(enable_services.sort)
      end
    end

    describe "#disabled_services" do
      it "returns all services marked as disabled" do
        enable_services = ["1", "a", "b", "c"]
        enable_services.each do |service|
          ServicesProposal.enable_service(service)
        end

        disable_services = ["1", "d", "e", "f"]
        disable_services.each do |service|
          ServicesProposal.disable_service(service)
        end

        expect(ServicesProposal.disabled_services.sort).to eq(disable_services.sort)
      end
    end
  end
end
