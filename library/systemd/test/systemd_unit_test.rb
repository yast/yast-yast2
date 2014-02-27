#!/usr/bin/env rspec

require_relative 'test_helper'
require 'yast2/systemd_unit'

module Yast
  describe SystemdUnit do
    include SystemdSocketStubs

    def trigger_reloading_properties command
      unit = SystemdUnit.new("new.socket")
      properties = unit.properties
      unit.send(command)
      expect(unit.properties).not_to equal(properties)
    end

    before do
      stub_sockets
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
        expect(unit.properties[:running?]).not_to be_nil
        expect(unit.properties[:loaded?]).not_to be_nil
        expect(unit.properties[:supported?]).not_to be_nil
        expect(unit.properties[:not_found?]).not_to be_nil
        expect(unit.properties[:path]).not_to be_nil
        expect(unit.properties[:errors]).not_to be_nil
        expect(unit.properties[:raw]).not_to be_nil
      end

      it "delegates the status properties onto the unit object" do
        unit = SystemdUnit.new("iscsid.socket")
        expect(unit).to respond_to(:enabled?)
        expect(unit).to respond_to(:active?)
        expect(unit).to respond_to(:running?)
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

      it "raises an exception if unsupported unit name is passed" do
        expect { SystemdUnit.new("random.unit")    }.to raise_error
      end

      it "accepts parameters to extend the default properties" do
        unit = SystemdUnit.new("iscsid.socket", :requires => "Requires", :wants => "Wants")
        expect(unit.properties.wants).not_to be_nil
        expect(unit.properties.requires).not_to be_nil
      end
    end

    describe "#stop" do
      it "returns true if unit has been stopped" do
        stub_unit_command
        unit = SystemdUnit.new("my.socket")
        expect(unit.stop).to be_true
      end

      it "returns false if failed" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.stop).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:stop)
      end
    end

    describe "#start" do
      it "returns true if starts (activates) the unit" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("my.socket")
        expect(unit.start).to be_true
      end

      it "returns false if failed to start the unit" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.start).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:start)
      end
    end

    describe "#enable" do
      it "returns true if the unit has been enabled successfully" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_true
      end

      it "returns false if unit fails" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_false
      end

      it "triggers reloading of unit properties" do
        trigger_reloading_properties(:enable)
      end
    end

    describe "#disable" do
      it "returns true if the unit has been disabled successfully" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("your.socket")
        expect(unit.disable).to be_true
      end

      it "returns false if unit disabling fails" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("your.socket")
        expect(unit.disable).to be_false
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

    describe "#errors" do
      it "returns empty string if the unit commands succeed" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("your.socket")
        unit.start
        expect(unit.errors).to be_empty

        unit.stop
        expect(unit.errors).to be_empty

        unit.enable
        expect(unit.errors).to be_empty

        unit.disable
        expect(unit.errors).to be_empty
      end

      it "returns error string if the unit commands fail" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("your.socket")
        unit.start
        expect(unit.errors).not_to be_empty

        unit.stop
        expect(unit.errors).not_to be_empty

        unit.enable
        expect(unit.errors).not_to be_empty

        unit.disable
        expect(unit.errors).not_to be_empty
      end
    end

  end
end
