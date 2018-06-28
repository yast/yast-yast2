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

    describe "#socket" do
      it "returns nil if service does not have socket" do
        service = SystemdService.find("sshd")
        expect(service.socket).to eq nil
      end

      it "returns a socket that can start service" do
        stub_services(service: "cups")
        service = SystemdService.find("cups")
        expect(service.socket).to be_a Yast::SystemdSocketClass::Socket
      end
    end

    describe "#enabled?" do
      subject(:service) { SystemdService.find("cups") }

      before do
        allow(service).to receive(:start_mode).and_return(start_mode)
        stub_services(service: "cups")
      end

      context "when the start mode is :boot" do
        let(:start_mode) { :boot }

        it "returns true" do
          expect(service).to be_enabled
        end
      end

      context "when the start mode is :demand" do
        let(:start_mode) { :demand }

        it "returns true" do
          expect(service).to be_enabled
        end
      end

      context "when the start mode is :manual" do
        let(:start_mode) { :manual }

        it "returns false" do
          expect(service).to_not be_enabled
        end
      end
    end

    describe "#start_mode" do
      let(:enabled_on_boot?) { true }
      let(:socket) { double("socket", enabled?: true) }

      subject(:service) { SystemdService.find("cups") }

      before do
        stub_services(service: "cups")
        allow(service).to receive(:socket).and_return(socket)
        allow(service).to receive(:enabled_on_boot?).and_return(enabled_on_boot?)
      end

      context "when the service is enabled" do
        it "returns :boot" do
          expect(service.start_mode).to eq(:boot)
        end
      end

      context "when the service is disabled" do
        let(:enabled_on_boot?) { false }

        context "but the associated socket is enabled" do
          it "returns :demand" do
            expect(service.start_mode).to eq(:demand)
          end
        end

        context "and the socket is disabled" do
          let(:socket) { double("socket", enabled?: false) }

          it "returns :manual" do
            expect(service.start_mode).to eq(:manual)
          end
        end

        context "and there is no socket" do
          let(:socket) { nil }

          it "returns :manual" do
            expect(service.start_mode).to eq(:manual)
          end
        end
      end
    end

    describe "#start_mode=" do
      subject(:service) { SystemdService.find("cups") }
      let(:socket) { double("socket", disable: true) }

      before do
        stub_services(service: "cups")
        allow(service).to receive(:socket).and_return(socket)
        allow(service).to receive(:disable)
      end

      context "when no argument is given" do
        it "enables the service to start on boot" do
          expect(socket).to_not receive(:enable)
          service.start_mode = :boot
        end
      end

      context "when :boot mode is given" do
        it "enables the service to start on boot" do
          expect(service).to receive(:enable_service)
          expect(socket).to_not receive(:enable)
          service.start_mode = :boot
        end
      end

      context "when :demand mode is given" do
        it "enables the socket" do
          expect(service).to_not receive(:enable_service)
          expect(socket).to receive(:enable)
          service.start_mode = :demand
        end
      end

      context "when :manual mode is given" do
        it "disables the service and the socket" do
          expect(service).to receive(:disable_service)
          expect(socket).to receive(:disable)
          service.start_mode = :manual
        end
      end
    end

    describe "#start_modes" do
      subject(:service) { SystemdService.find("cups") }

      before do
        stub_services(service: "cups")
        allow(service).to receive(:socket).and_return(socket)
      end

      context "when an associated socket exists" do
        let(:socket) { double("socket", disable: true) }

        it "returns :boot, :demand and :manual" do
          expect(service.start_modes).to eq([:boot, :demand, :manual])
        end
      end

      context "when no associated socket exists" do
        let(:socket) { nil }

        it "returns :boot and :manual" do
          expect(service.start_modes).to eq([:boot, :manual])
        end
      end
    end

    describe "#enable" do
      subject(:service) { SystemdService.find("cups") }

      before do
        stub_services(service: "cups")
      end

      it "sets start_mode to :boot" do
        expect(service).to receive(:start_mode=).with(:boot)
        service.enable
      end
    end

    describe "#disable" do
      subject(:service) { SystemdService.find("cups") }

      before do
        stub_services(service: "cups")
      end

      it "sets start_mode to :manual" do
        expect(service).to receive(:start_mode=).with(:manual)
        service.disable
      end
    end

    describe "#socket?" do
      subject(:service) { SystemdService.find("cups") }

      before do
        allow(service).to receive(:socket).and_return(socket)
      end

      context "when there is an associated socket" do
        let(:socket) { double("socket") }

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

      before { stub_services(service: service_name) }

      context "when the service is triggered by a socket" do
        let(:service_name) { "cups" }

        it "returns the socket" do
          expect(service.socket).to be_a(Yast::SystemdSocketClass::Socket)
          expect(service.socket.unit_name).to eq("iscsid")
        end
      end

      context "when the service is not triggered by a socket" do
        let(:service_name) { "sshd" }

        it "returns nil" do
          expect(service.socket).to be_nil
        end
      end
    end

    describe "#socket?" do
      subject(:service) { SystemdService.find(service_name) }

      before { stub_services(service: service_name) }

      context "when there is an associated socket" do
        let(:service_name) { "cups" }

        it "returns true" do
          expect(service.socket?).to eq(true)
        end
      end

      context "when there is no associated socket" do
        let(:service_name) { "sshd" }

        it "returns false" do
          expect(service.socket?).to eq(false)
        end
      end
    end
  end
end
