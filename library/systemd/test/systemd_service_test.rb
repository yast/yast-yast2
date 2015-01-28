#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  import "SystemdService"

  describe SystemdService do
    include SystemdServiceStubs

    before do
      stub_services
    end

    describe ".find" do
      it "returns the service unit object specified in parameter" do
        ["sshd", "sshd.service"].each do |service_name|
          service = SystemdService.find(service_name)
          expect(service).to be_a(SystemdUnit)
          expect(service.unit_type).to eq("service")
          expect(service.unit_name).to eq("sshd")
        end
      end

      it "returns nil if the service unit does not exist" do
        stub_services(service: "unknown")
        service = SystemdService.find("unknown")
        expect(service).to be_nil
      end
    end

    describe ".find!" do
      it "returns the service unit object specified in parameter" do
        service = SystemdService.find("sshd")
        expect(service).to be_a(SystemdUnit)
        expect(service.unit_type).to eq("service")
        expect(service.unit_name).to eq("sshd")
      end

      it "raises SystemdServiceNotFound error if unit does not exist" do
        stub_services(service: "unknown")
        expect { SystemdService.find!("unknown") }.to raise_error(SystemdServiceNotFound)
      end
    end

    describe ".all" do
      it "returns all supported services found" do
        services = SystemdService.all
        expect(services).to be_a(Array)
        expect(services).not_to be_empty
        services.each { |s| expect(s.unit_type).to eq("service") }
      end
    end

    describe "#running?" do
      it "returns true if the service is running" do
        service = SystemdService.find "sshd"
        expect(service).to respond_to(:running?)
        expect(service.running?).to be_true
      end
    end

    describe "#pid" do
      it "returns the pid of the running service" do
        service = SystemdService.find("sshd")
        expect(service).to respond_to(:pid)
        expect(service.pid).not_to be_empty
      end
    end

    context "Start a service on the installation system" do
      it "starts a service with a specialized inst-sys helper if available" do
        File.stub(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        SCR.stub(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.start).to be_true
      end
    end

    context "Restart a service on the installation system" do
      it "restarts a service with a specialized inst-sys helper if available" do
        SystemdServiceClass::Service.any_instance.stub(:sleep).and_return(1)
        File.stub(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        SCR.stub(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).to receive(:stop).ordered.and_call_original
        expect(service).to receive(:start).ordered.and_call_original
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.restart).to be_true
      end
    end

    context "Stop a service on the installation system" do
      it "stops a service with a specialized inst-sys helper" do
        File.stub(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        SCR.stub(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.stop).to be_true
      end
    end
  end
end
