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

      context "when the service does not exist" do
        before do
          properties = OpenStruct.new(
            stdout: "", stderr: "Unit unknown.service could not be found.", exit: 1
          )
          allow_any_instance_of(Yast::SystemdUnit::Properties)
            .to receive(:load_systemd_properties)
            .and_return(properties)
        end

        it "returns nil" do
          service = SystemdService.find("another")
          expect(service).to be_nil
        end
      end
    end

    describe ".build" do
      it "returns the service unit object specified in parameter" do
        ["sshd", "sshd.service"].each do |service_name|
          service = SystemdService.build(service_name)
          expect(service).to be_a(SystemdUnit)
          expect(service.unit_type).to eq("service")
          expect(service.unit_name).to eq("sshd")
        end
      end

      it "returns a service instance even if the real service does not exist" do
        stub_services(service: "unknown")
        service = SystemdService.build("unknown")
        expect(service.name).to eq("unknown")
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

    describe ".find_many" do
      let(:systemctl_show) { OpenStruct.new(stdout: systemctl_stdout, stderr: "", exit: 0) }
      let(:apparmor_double) { double("Service", name: "apparmor") }
      let(:cups_double) { double("Service", name: "cups") }
      let(:systemctl_stdout) do
        File.read(File.join(__dir__, "data", "apparmor_and_cups_properties"))
      end

      before do
        allow(Yast::Systemctl).to receive(:execute).with(
          "show  --property=Id,MainPID,Description,LoadState,ActiveState,SubState,UnitFileState," \
          "FragmentPath,CanReload,TriggeredBy apparmor.service cups.service"
        ).and_return(systemctl_show)
        allow(SystemdService).to receive(:find).with("apparmor", {}).and_return(apparmor_double)
        allow(SystemdService).to receive(:find).with("cups", {}).and_return(cups_double)
      end

      it "returns the list of services" do
        services = SystemdService.find_many(["apparmor", "cups"])
        expect(services).to contain_exactly(
          an_object_having_attributes("name" => "apparmor"),
          an_object_having_attributes("name" => "cups")
        )
      end

      it "includes 'TriggeredBy' property" do
        cups = SystemdService.find_many(["apparmor", "cups"]).last
        expect(cups.properties.triggered_by).to eq("cups.path cups.socket")
      end

      context "when 'systemctl show' fails to provide services information" do
        let(:systemctl_show) { OpenStruct.new(stdout: "", stderr: "", exit: 1) }

        it "retrieve services information in a one-by-one basis" do
          expect(SystemdService.find_many(["apparmor", "cups"]))
            .to eq([apparmor_double, cups_double])
        end
      end

      context "when 'systemctl show' displays some error" do
        let(:systemctl_show) { OpenStruct.new(stdout: "", stderr: "error", exit: 1) }

        it "retrieve services information in a one-by-one basis" do
          expect(SystemdService.find_many(["apparmor", "cups"]))
            .to eq([apparmor_double, cups_double])
        end
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
        expect(service.running?).to eq(true)
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
        allow(File).to receive(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        allow(SCR).to receive(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.start).to eq(true)
      end
    end

    context "Restart a service on the installation system" do
      it "restarts a service with a specialized inst-sys helper if available" do
        allow_any_instance_of(SystemdServiceClass::Service).to receive(:sleep).and_return(1)
        allow(File).to receive(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        allow(SCR).to receive(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).to receive(:stop).ordered.and_call_original
        expect(service).to receive(:start).ordered.and_call_original
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.restart).to eq(true)
      end
    end

    context "Stop a service on the installation system" do
      it "stops a service with a specialized inst-sys helper" do
        allow(File).to receive(:exist?).with("/bin/service_start").and_return(true)
        service = SystemdService.find("sshd")
        allow(SCR).to receive(:Execute).and_return("stderr" => "", "stdout" => "", "exit" => 0)
        expect(service).not_to receive(:command) # SystemdUnit#command
        expect(service.stop).to eq(true)
      end
    end

    describe "#socket" do
      subject(:service) { SystemdService.find(service_name) }
      let(:service_name) { "sshd" }
      let(:socket) { instance_double(SystemdSocketClass::Socket) }

      it "returns the socket for the service" do
        expect(SystemdSocket).to receive(:for_service).with(service_name)
          .and_return(socket)
        expect(service.socket).to eq(socket)
      end

      it "asks for the socket only once" do
        expect(SystemdSocket).to receive(:for_service).with(service_name)
          .and_return(socket).once
        expect(service.socket).to eq(socket)
        expect(service.socket).to eq(socket)
      end

      context "when no associated socket is found" do
        before do
          allow(SystemdSocket).to receive(:for_service).with(service_name)
            .and_return(nil)
        end

        it "returns nil" do
          expect(service.socket).to be_nil
        end
      end
    end

    describe "#socket?" do
      subject(:service) { SystemdService.find("sshd") }

      before do
        allow(service).to receive(:socket).and_return(socket)
      end

      context "when there is an associated socket" do
        let(:socket) { instance_double(SystemdSocketClass::Socket) }

        it "returns true" do
          expect(service.socket?).to eq(true)
        end
      end

      context "when there is no associated socket" do
        let(:socket) { nil }

        it "returns false" do
          expect(service.socket?).to eq(false)
        end
      end
    end
  end
end
