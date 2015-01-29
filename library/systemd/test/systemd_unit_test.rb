#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  describe SystemdUnit do
    include SystemdSocketStubs
    include SystemdServiceStubs

    def trigger_reloading_properties(command)
      unit = SystemdUnit.new("new.socket")
      properties = unit.properties
      unit.send(command)
      expect(unit.properties).not_to equal(properties)
    end

    before do
      stub_sockets
      stub_services
    end

    context "Installation system without full support of systemd" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return(true)
      end

      describe "#properties" do
        context "Unit found" do
          it "returns struct with restricted installation properties" do
            allow_any_instance_of(SystemdUnit).to receive(:command)
              .with("is-enabled sshd.service").and_return(
                OpenStruct.new("stderr" => "", "stdout" => "enabled", "exit" => 0)
              )
            unit = SystemdUnit.new("sshd.service")
            expect(unit.properties).to be_a(SystemdUnit::InstallationProperties)
            expect(unit.properties.not_found?).to be_falsey
          end

          describe "#enabled?" do
            it "returns true if service is enabled" do
              allow_any_instance_of(SystemdUnit).to receive(:command)
                .with("is-enabled sshd.service").and_return(
                  OpenStruct.new("stderr" => "", "stdout" => "enabled", "exit" => 0)
                )
              unit = SystemdUnit.new("sshd.service")
              expect(unit.enabled?).to be_truthy
            end

            it "returns false if service is disabled" do
              stub_unit_command(success: false)
              allow_any_instance_of(SystemdUnit).to receive(:command)
                .with("is-enabled sshd.service").and_return(
                  OpenStruct.new("stderr" => "", "stdout" => "disabled", "exit" => 1)
                )
              unit = SystemdUnit.new("sshd.service")
              expect(unit.enabled?).to be_falsey
            end
          end
        end

        context "Unit not found" do
          it "returns struct with restricted installation properties" do
            stub_services(service: "unknown")
            stub_unit_command(success: false)
            unit = SystemdUnit.new("unknown.service")
            expect(unit.properties).to be_a(SystemdUnit::InstallationProperties)
            expect(unit.properties.not_found?).to be_truthy
          end
        end
      end
    end

    describe "#properties" do
      it "always returns struct including default properties" do
        unit = SystemdUnit.new("iscsi.socket")
        expect(unit.properties.to_h.keys).to include(*SystemdUnit::DEFAULT_PROPERTIES.keys)
      end

      it "provides status properties methods" do
        unit = SystemdUnit.new("iscsid.socket")
        expect(unit.properties[:enabled?]).not_to be_nil
        expect(unit.properties[:active?]).not_to be_nil
        expect(unit.properties[:loaded?]).not_to be_nil
        expect(unit.properties[:supported?]).not_to be_nil
        expect(unit.properties[:not_found?]).not_to be_nil
        expect(unit.properties[:path]).not_to be_nil
        expect(unit.properties[:error]).not_to be_nil
        expect(unit.properties[:raw]).not_to be_nil
      end

      it "delegates the status properties onto the unit object" do
        unit = SystemdUnit.new("iscsid.socket")
        expect(unit).to respond_to(:enabled?)
        expect(unit).to respond_to(:active?)
        expect(unit).to respond_to(:loaded?)
        expect(unit).to respond_to(:path)
      end
    end

    describe ".new" do
      it "creates a new SystemdUnit instance with unit name and type parsed from first parameter" do
        instance = SystemdUnit.new("random.socket")
        expect { SystemdUnit.new("random.socket") }.not_to raise_error
        expect(instance.unit_name).to eq("random")
        expect(instance.unit_type).to eq("socket")
      end

      it "raises an exception if an incomplete unit name is passed" do
        expect { SystemdUnit.new("sshd") }.to raise_error
      end

      it "allows to create supported units" do
        expect { SystemdUnit.new("my.socket")      }.not_to raise_error
        expect { SystemdUnit.new("default.target") }.not_to raise_error
        expect { SystemdUnit.new("sshd.service")   }.not_to raise_error
      end

      it "accepts parameters to extend the default properties" do
        unit = SystemdUnit.new("iscsid.socket", requires: "Requires", wants: "Wants")
        expect(unit.properties.wants).not_to be_nil
        expect(unit.properties.requires).not_to be_nil
      end
    end

    describe "#stop" do
      it "returns true if unit has been stopped" do
        stub_unit_command
        unit = SystemdUnit.new("my.socket")
        expect(unit.stop).to be_truthy
      end

      it "returns false if failed" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.stop).to be_falsey
        expect(unit.error).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:stop)
      end
    end

    describe "#start" do
      it "returns true if starts (activates) the unit" do
        stub_unit_command(success: true)
        unit = SystemdUnit.new("my.socket")
        expect(unit.start).to be_truthy
      end

      it "returns false if failed to start the unit" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.start).to be_falsey
        expect(unit.error).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:start)
      end
    end

    describe "#enable" do
      it "returns true if the unit has been enabled successfully" do
        stub_unit_command(success: true)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_truthy
      end

      it "returns false if unit fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_falsey
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:enable)
      end
    end

    describe "#disable" do
      it "returns true if the unit has been disabled successfully" do
        stub_unit_command(success: true)
        unit = SystemdUnit.new("your.socket")
        expect(unit.disable).to be_truthy
      end

      it "returns false if unit disabling fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("your.socket")
        expect(unit.disable).to be_falsey
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:disable)
      end
    end

    describe "#show" do
      it "always returns new unit properties object" do
        unit = SystemdUnit.new("startrek.socket")
        expect(unit.show).not_to equal(unit.show)
      end
    end

    describe "#refresh!" do
      it "rewrites and returns the properties instance variable" do
        unit = SystemdUnit.new("your.socket")
        properties = unit.properties
        expect(unit.refresh!).not_to equal(properties)
      end
    end

    describe "#restart" do
      it "returns true if unit has been restarted" do
        unit = SystemdUnit.new("sshd.service")
        expect(unit.restart).to be_truthy
      end

      it "returns false if the restart fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("sshd.service")
        expect(unit.restart).to be_falsey
      end
    end

    describe "#try_restart" do
      it "returns true if the unit has been restarted" do
        unit = SystemdUnit.new("sshd.service")
        expect(unit.try_restart).to be_truthy
      end

      it "returns false if the try_restart fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("sshd.service")
        expect(unit.try_restart).to be_falsey
      end
    end

    describe "#reload" do
      it "returns true if the unit has been reloaded" do
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload).to be_truthy
      end

      it "returns false if the reload fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload).to be_falsey
      end
    end

    describe "#reload_or_restart" do
      it "returns true if the unit has been reloaded or restarted" do
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload_or_restart).to be_truthy
      end

      it "returns false if the reload_or_restart action fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload_or_restart).to be_falsey
      end
    end

    describe "#reload_or_try_restart" do
      it "returns true if the unit has been reload_or_try_restarted" do
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload_or_try_restart).to be_truthy
      end

      it "returns false if the reload_or_try_restart action fails" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("sshd.service")
        expect(unit.reload_or_try_restart).to be_falsey
      end
    end

    describe "#error" do
      it "returns empty string if the unit commands succeed" do
        stub_unit_command(success: true)
        unit = SystemdUnit.new("your.socket")
        unit.start
        expect(unit.error).to be_empty

        unit.stop
        expect(unit.error).to be_empty

        unit.enable
        expect(unit.error).to be_empty

        unit.disable
        expect(unit.error).to be_empty
      end

      it "returns error string if the unit commands fail" do
        stub_unit_command(success: false)
        unit = SystemdUnit.new("your.socket")
        unit.start
        expect(unit.error).not_to be_empty

        unit.stop
        expect(unit.error).not_to be_empty

        unit.enable
        expect(unit.error).not_to be_empty

        unit.disable
        expect(unit.error).not_to be_empty
      end
    end
  end
end
