#!/usr/bin/env rspec

require_relative "../test_helper"

require "yast2/service_configuration"

describe Yast2::ServiceConfiguration do
  describe ".new" do
    it "raises ArgumentError if non service is passed" do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#read" do
    context "reading status" do
      it "sets status to :active if all passed services is active" do
        service1 = double(active?: true, is_a?: true).as_null_object
        service2 = double(active?: true, is_a?: true).as_null_object
        service_configuration = described_class.new(service1, service2)

        service_configuration.read
        expect(service_configuration.status).to eq :active
      end

      it "sets status to :inactive if all passed services is not active" do
        service1 = double(active?: false, is_a?: true).as_null_object
        service2 = double(active?: false, is_a?: true).as_null_object
        service_configuration = described_class.new(service1, service2)

        service_configuration.read
        expect(service_configuration.status).to eq :inactive
      end

      it "sets status to :inconsistent if only some services is active" do
        service1 = double(active?: false, is_a?: true).as_null_object
        service2 = double(active?: true, is_a?: true).as_null_object
        service_configuration = described_class.new(service1, service2)

        service_configuration.read
        expect(service_configuration.status).to eq :inconsistent
      end
    end

    context "reading auto start" do
      # TODO: write after start using startmode
    end
  end

  describe "#write" do
    context "writting action" do
      # TODO: it should delegate this logic with sockets to systemservice
      it "calls start if action is :start" do
        service1 = double(is_a?: true).as_null_object
        socket1 = double.as_null_object
        service2 = double(is_a?: true, socket: socket1).as_null_object
        service_configuration = described_class.new(service1, service2)

        service_configuration.action = :start
        expect(service1).to receive(:start)
        expect(service2).to_not receive(:start)
        expect(socket1).to receive(:start)
        service_configuration.write
      end

      it "calls stop if action is :stop" do
        service1 = double(is_a?: true).as_null_object
        service_configuration = described_class.new(service1)

        service_configuration.action = :stop
        expect(service1).to receive(:stop)
        service_configuration.write
      end

      it "calls restart if action is :restart" do
        service1 = double(is_a?: true).as_null_object
        service_configuration = described_class.new(service1)

        service_configuration.action = :restart
        expect(service1).to receive(:restart)
        service_configuration.write
      end

      it "calls reload or restart if action is :reload" do
        service1 = double(is_a?: true).as_null_object
        service_configuration = described_class.new(service1)

        service_configuration.action = :reload
        expect(service1).to receive(:reload_or_restart)
        service_configuration.write
      end

      it "does nothing if action is :nothing" do
        service1 = double(is_a?: true, active?: false, socket: nil, enabled?: false, "start_mode=": nil)
        service_configuration = described_class.new(service1)

        service_configuration.action = :nothing
        service_configuration.write
      end
    end

    context "writting auto start" do
      # TODO: write after start using start_mode in system service
    end

  end
end
