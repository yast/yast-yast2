#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "yast2/system_service"

describe Yast2::SystemService do
  subject(:system_service) { described_class.new(service) }

  let(:service) do
    instance_double(Yast::SystemdServiceClass::Service,
      name:     "cups",
      enabled?: service_enabled,
      active?:  service_active,
      refresh!: true)
  end

  let(:service_enabled) { true }
  let(:service_active) { true }

  let(:service_socket) do
    instance_double(Yast::SystemdSocketClass::Socket,
      enabled?: socket_enabled,
      active?:  socket_active)
  end

  let(:socket_enabled) { true }
  let(:socket_active) { true }

  let(:socket) { service_socket }

  before do
    allow(service).to receive(:socket).and_return(socket)
  end

  describe ".find" do
    let(:systemd_service) { instance_double(Yast::SystemdServiceClass::Service) }

    before do
      allow(Yast::SystemdService).to receive(:find).with("cups").and_return(systemd_service)
    end

    it "finds a systemd service" do
      system_service = described_class.find("cups")
      expect(system_service).to be_a(described_class)
      expect(system_service.service).to eq(systemd_service)
    end
  end

  describe ".find_many" do
    let(:apparmor) { instance_double(Yast::SystemdServiceClass::Service) }
    let(:cups) { instance_double(Yast::SystemdServiceClass::Service) }

    before do
      allow(Yast::SystemdService).to receive(:find_many).with(["apparmor", "cups"])
        .and_return([apparmor, cups])
    end

    it "finds a set of systemd services" do
      system_services = described_class.find_many(["apparmor", "cups"])
      expect(system_services).to be_all(Yast2::SystemService)
      expect(system_services.map(&:service)).to eq([apparmor, cups])
    end

    context "when some service is not found" do
      before do
        allow(Yast::SystemdService).to receive(:find_many).with(["apparmor", "cups"])
          .and_return([nil, cups])
      end

      it "ignores the not found service" do
        system_services = described_class.find_many(["apparmor", "cups"])
        expect(system_services.map(&:service)).to eq([cups])
      end
    end
  end

  describe "#current_start_mode" do
    context "when the service is enabled" do
      let(:service_enabled) { true }

      it "returns :on_boot" do
        expect(system_service.current_start_mode).to eq(:on_boot)
      end
    end

    context "when the service is disabled" do
      let(:service_enabled) { false }

      context "and has an associated socked" do
        let(:socket) { service_socket }

        context "and the socket is enabled" do
          let(:socket_enabled) { true }

          it "returns :on_demand" do
            expect(system_service.current_start_mode).to eq(:on_demand)
          end
        end

        context "and the socket is disabled" do
          let(:socket_enabled) { false }

          it "returns :manual" do
            expect(system_service.current_start_mode).to eq(:manual)
          end
        end
      end

      context "and has no an associated socket" do
        let(:socket) { nil }

        it "returns :manual" do
          expect(system_service.current_start_mode).to eq(:manual)
        end
      end
    end
  end

  describe "#current_active?" do
    context "when the service is active" do
      let(:service_active) { true }

      it "returns true" do
        expect(system_service.current_active?).to eq(true)
      end
    end

    context "when the service is not active" do
      let(:service_active) { false }

      context "and has an associated socket" do
        let(:socket) { service_socket }

        context "and the socket is active" do
          let(:socket_active) { true }

          it "returns true" do
            expect(system_service.current_active?).to eq(true)
          end
        end

        context "and the socket is not active" do
          let(:socket_active) { false }

          it "returns false" do
            expect(system_service.current_active?).to eq(false)
          end
        end
      end

      context "and has no associated socket" do
        let(:socket) { nil }

        it "returns false" do
          expect(system_service.current_active?).to eq(false)
        end
      end
    end
  end

  describe "#start_modes" do
    context "when the service has an associated socket" do
      let(:socket) { service_socket }

      it "returns :on_boot, :on_demand and :manual" do
        expect(system_service.start_modes).to contain_exactly(:on_boot, :manual, :on_demand)
      end
    end

    context "when the service has no associated socket" do
      let(:socket) { nil }

      it "returns :on_boot and :manual" do
        expect(system_service.start_modes).to contain_exactly(:on_boot, :manual)
      end
    end
  end

  describe "#start_mode" do
    context "when the start mode has not been changed" do
      it "returns the current start mode" do
        expect(system_service.start_mode).to eq(:on_boot)
      end
    end

    context "when the start mode has been changed" do
      before do
        system_service.start_mode = :manual
      end

      it "returns the new start mode" do
        expect(system_service.start_mode).to eq(:manual)
      end
    end
  end

  describe "#start_mode=" do
    it "caches the wanted start_mode" do
      expect { system_service.start_mode = :on_demand }.to change { system_service.start_mode }
        .from(:on_boot).to(:on_demand)
    end

    context "when an invalid value is given" do
      it "raises an error" do
        expect { system_service.start_mode = :other }.to raise_error(ArgumentError)
      end
    end

    context "when the wanted start_mode is the same than the current one" do
      before do
        system_service.start_mode = :on_demand
      end

      it "ignores the change" do
        system_service.start_mode = :on_boot
        expect(system_service.changed?).to eq(false)
      end
    end
  end

  describe "#support_start_on_demand?" do
    context "when the service has an associated socket" do
      let(:socket) { service_socket }

      it "returns true" do
        expect(system_service.support_start_on_demand?).to eq(true)
      end
    end

    context "when the service has no associated socket" do
      let(:socket) { nil }

      it "returns false" do
        expect(system_service.support_start_on_demand?).to eq(false)
      end
    end
  end

  describe "#active?" do
    context "when no action has been performed over the system service" do
      context "and the underlying service is active" do
        let(:service_active) { true }

        it "returns true" do
          expect(system_service.active?).to eq(true)
        end
      end

      context "and the underlying service is not active" do
        let(:service_active) { false }
        let(:socket) { nil }

        it "returns false" do
          expect(system_service.active?).to eq(false)
        end
      end
    end

    context "when service was set to be started" do
      let(:service_active) { false }

      before do
        system_service.start
      end

      it "returns true" do
        expect(system_service.active?).to eq(true)
      end
    end

    context "when service was set to be stopped" do
      let(:service_active) { true }

      before do
        system_service.stop
      end

      it "returns false" do
        expect(system_service.active?).to eq(false)
      end
    end

    context "when service was set to be restarted" do
      let(:service_active) { false }

      before do
        system_service.restart
      end

      it "returns true" do
        expect(system_service.active?).to eq(true)
      end
    end

    context "when service was set to be reloaded" do
      let(:service_active) { false }

      before do
        system_service.reload
      end

      it "returns true" do
        expect(system_service.active?).to eq(true)
      end
    end
  end

  describe "#keywords" do
    before do
      allow(service).to receive(:id).and_return("cups.service")
    end

    context "when the service has no associated socket" do
      let(:socket) { nil }

      it "returns only the service full name" do
        expect(system_service.keywords).to contain_exactly("cups.service")
      end
    end

    context "when the service has an associated socket" do
      let(:socket) { service_socket }

      before do
        allow(socket).to receive(:id).and_return("cups.socket")
      end

      it "returns the service and socket full names" do
        expect(system_service.keywords).to contain_exactly("cups.service", "cups.socket")
      end
    end
  end

  describe "#start" do
    it "sets the action to :start" do
      system_service.start

      expect(system_service.action).to eq(:start)
    end

    context "when the service is not active" do
      let(:service_active) { false }
      let(:socket) { nil }

      it "sets the service to be active" do
        expect { system_service.start }.to change { system_service.active? }
          .from(false).to(true)
      end

      it "sets the service as changed" do
        expect { system_service.start }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end

    context "when the service is already active (started)" do
      let(:service_active) { true }

      it "sets the service to stay as active" do
        expect { system_service.start }.to_not change { system_service.active? }
      end

      it "ignores the change" do
        system_service.start
        expect(system_service.changed?).to eq(false)
      end
    end

    context "and the service was set to be stopped previously" do
      before do
        system_service.stop
      end

      it "sets the service to stay as active" do
        expect { system_service.start }.to change { system_service.active? }
          .from(false).to(true)
      end

      it "cancels the previous change" do
        system_service.start
        expect(system_service.changed?).to eq(false)
      end
    end
  end

  describe "#stop" do
    it "sets the action to :stop" do
      system_service.stop

      expect(system_service.action).to eq(:stop)
    end

    context "when the service is active" do
      let(:service_active) { true }

      it "sets the service to be deactivated" do
        expect { system_service.stop }.to change { system_service.active? }
          .from(true).to(false)
      end

      it "sets the service as changed" do
        expect { system_service.stop }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end

    context "when the service is already stopped (inactive)" do
      let(:service_active) { false }
      let(:socket) { nil }

      it "sets the service to stay as inactive" do
        expect { system_service.stop }.to_not change { system_service.active? }
      end

      it "ignores the change" do
        system_service.stop
        expect(system_service.changed?).to eq(false)
      end

      context "and the service was set to be started previously" do
        before do
          system_service.start
        end

        it "sets the service to stay as inactive" do
          expect { system_service.stop }.to change { system_service.active? }
            .from(true).to(false)
        end

        it "cancels the previous change" do
          system_service.stop
          expect(system_service.changed?).to eq(false)
        end
      end
    end
  end

  describe "#restart" do
    it "sets the action to :restart" do
      system_service.restart

      expect(system_service.action).to eq(:restart)
    end

    context "when the service is already active" do
      let(:service_active) { true }

      it "sets the service to stay as active" do
        expect { system_service.restart }.to_not change { system_service.active? }
      end

      it "sets the service as changed" do
        expect { system_service.restart }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end

    context "when the service is not active" do
      let(:service_active) { false }
      let(:socket) { nil }

      it "sets the service to be active" do
        expect { system_service.restart }.to change { system_service.active? }
          .from(false).to(true)
      end

      it "sets the service as changed" do
        expect { system_service.restart }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end
  end

  describe "#reload" do
    it "sets the action to :reload" do
      system_service.reload

      expect(system_service.action).to eq(:reload)
    end

    context "when the service is already active" do
      let(:service_active) { true }

      it "sets the service to stay as active" do
        expect { system_service.reload }.to_not change { system_service.active? }
      end

      it "sets the service as changed" do
        expect { system_service.reload }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end

    context "when the service is not active" do
      let(:service_active) { false }
      let(:socket) { nil }

      it "sets the service to be active" do
        expect { system_service.reload }.to change { system_service.active? }
          .from(false).to(true)
      end

      it "sets the service as changed" do
        expect { system_service.reload }.to change { system_service.changed_value?(:active) }
          .from(false).to(true)
      end
    end
  end

  describe "#save=" do
    before do
      allow(service).to receive(:enable).and_return(true)
      allow(service).to receive(:disable).and_return(true)

      allow(service_socket).to receive(:enable).and_return(true)
      allow(service_socket).to receive(:disable).and_return(true)
    end

    it "resets the changes and refreshes the service" do
      expect(system_service).to receive(:reset)
      expect(system_service).to receive(:refresh)

      system_service.save
    end

    context "when start mode has changed" do
      before do
        system_service.start_mode = start_mode
      end

      context "and the new start mode is :on_boot" do
        # current start_mode is :manual
        let(:service_enabled) { false }
        let(:socket) { nil }

        let(:start_mode) { :on_boot }

        it "enables the service" do
          expect(service).to receive(:enable).and_return(true)

          system_service.save
        end

        context "and the service has an associated socket" do
          let(:socket) { service_socket }
          let(:socket_enabled) { false }

          it "disables the socket" do
            allow(service).to receive(:enable).and_return(true)
            expect(socket).to receive(:disable).and_return(true)

            system_service.save
          end
        end
      end

      context "and the new start mode is :on_demand" do
        # current start_mode is :manual
        let(:service_enabled) { false }
        let(:socket_enabled) { false }

        let(:start_mode) { :on_demand }

        it "enables the socket and disables the service" do
          expect(socket).to receive(:enable).and_return(true)
          expect(service).to receive(:disable).and_return(true)

          system_service.save
        end
      end

      context "and the new start mode is :manual" do
        # current start_mode is :on_boot
        let(:service_enabled) { true }
        let(:socket) { nil }

        let(:start_mode) { :manual }

        it "disables the service" do
          expect(service).to receive(:disable).and_return(true)

          system_service.save
        end

        context "and the service has an associated socket" do
          let(:socket) { service_socket }
          let(:socket_enabled) { false }

          it "disables the socket" do
            allow(service).to receive(:disable).and_return(true)
            expect(socket).to receive(:disable).and_return(true)

            system_service.save
          end
        end
      end

      context "and there is a problem when trying to set the new start mode" do
        before do
          allow(service).to receive(:disable).and_return(false)
        end

        let(:start_mode) { :manual }

        it "registers an error" do
          system_service.save
          expect(system_service.errors).to eq(start_mode: :manual)
        end
      end
    end

    context "when an action is set (start, stop, restart, reload)" do
      before do
        system_service.start_mode = start_mode
        system_service.public_send(action)
      end

      let(:start_mode) { :on_boot }

      context "and the action is start" do
        let(:action) { :start }

        context "and neither the service nor the socket are active" do
          let(:service_active) { false }
          let(:socket_active) { false }

          context "and the start mode is set to :on_demand" do
            let(:start_mode) { :on_demand }

            it "tries to start the socket" do
              expect(socket).to receive(:start).and_return(true)

              system_service.save
            end

            it "does not try to start the service" do
              allow(socket).to receive(:start)
              expect(service).to_not receive(:start)

              system_service.save
            end
          end

          context "and the start mode is set to :on_boot or :manual" do
            let(:start_mode) { :manual }

            it "tries to start the service" do
              expect(service).to receive(:start).and_return(true)

              system_service.save
            end

            it "does not try to start the socket" do
              allow(service).to receive(:start)
              expect(socket).to_not receive(:start)

              system_service.save
            end
          end
        end

        context "and the service is active" do
          let(:service_active) { true }
          let(:socket_active) { false }

          it "does not try to start neither the socket nor the service" do
            expect(socket).to_not receive(:start)
            expect(service).to_not receive(:start)

            system_service.save
          end
        end

        context "and the socket is active" do
          let(:socket_active) { true }
          let(:service_active) { true }

          it "does not try to start neither the socket nor the service" do
            expect(socket).to_not receive(:start)
            expect(service).to_not receive(:start)

            system_service.save
          end
        end
      end

      context "and the action is stop" do
        let(:action) { :stop }

        before do
          allow(service).to receive(:stop).and_return(true)
          allow(socket).to receive(:stop).and_return(true)
        end

        context "and the service is active" do
          let(:service_active) { true }

          it "tries to stop the service" do
            expect(service).to receive(:stop).and_return(true)

            system_service.save
          end
        end

        context "and the socket is active" do
          let(:socket_active) { true }

          it "tries to stop the socket" do
            expect(socket).to receive(:stop).and_return(true)

            system_service.save
          end
        end

        context "and the service is not active" do
          let(:service_active) { false }

          it "does not try to stop the service again" do
            expect(service).to_not receive(:stop)
            system_service.save
          end
        end

        context "and the socket is not active" do
          let(:socket_active) { false }

          it "does not try to stop the socket again" do
            expect(socket).to_not receive(:stop)
            system_service.save
          end
        end
      end

      context "and the action is restart" do
        let(:action) { :restart }

        it "performs the stop action (see above)" do
          expect(system_service).to receive(:perform_stop)

          system_service.save
        end

        context "and the system service is correctly stopped" do
          before do
            allow(system_service).to receive(:perform_stop).and_return(true)
          end

          it "performs the start action (see above)" do
            expect(system_service).to receive(:perform_start)

            system_service.save
          end
        end
      end

      context "and the action is reload" do
        let(:action) { :reload }

        before do
          allow(service).to receive(:can_reload?).and_return(support_reload)
        end

        context "when the service does not support reload" do
          let(:support_reload) { false }

          it "performs the restart action (see above)" do
            expect(system_service).to receive(:perform_restart)

            system_service.save
          end
        end

        context "when the service supports reload" do
          let(:support_reload) { true }

          context "and the start mode is set to :on_demand" do
            let(:start_mode) { :on_demand }

            context "and the socket is active" do
              let(:socket_active) { true }

              context "and the service is active" do
                let(:service_active) { true }

                it "reloads the service" do
                  expect(service).to receive(:reload).and_return(true)

                  system_service.save
                end
              end
            end

            context "and the socket is not active" do
              let(:socket_active) { false }

              context "and the service is active" do
                let(:service_active) { true }

                it "reloads the service" do
                  expect(service).to receive(:reload).and_return(true)

                  system_service.save
                end
              end

              context "and the service is not active" do
                let(:service_active) { false }

                it "performs the start action (see above)" do
                  expect(system_service).to receive(:perform_start).and_return(true)

                  system_service.save
                end
              end
            end
          end

          context "and the start mode is :on_boot or :manual" do
            let(:start_mode) { :on_boot }

            let(:socket_active) { true }

            it "stops the socket if active" do
              allow(service).to receive(:reload)
              expect(socket).to receive(:stop).and_return(true)

              system_service.save
            end

            context "and the service is active" do
              let(:service_active) { true }

              it "reloads the service" do
                allow(socket).to receive(:stop)
                expect(service).to receive(:reload).and_return(true)

                system_service.save
              end
            end

            context "and the service is not ctive" do
              let(:service_active) { false }

              it "performs the start action (see above)" do
                allow(socket).to receive(:stop)
                expect(system_service).to receive(:perform_start).and_return(true)

                system_service.save
              end
            end
          end
        end
      end

      context "and the state must be kept" do
        let(:service_active) { false }
        let(:socket_active) { false }

        let(:action) { :start }

        it "does not perform the requested action" do
          expect(service).to_not receive(:start)
          expect(socket).to_not receive(:start)

          system_service.save(keep_state: true)
        end
      end

      context "and the action is successfully performed" do
        before do
          allow(service).to receive(:start).and_return(true)
          allow(socket).to receive(:start).and_return(true)
        end

        let(:service_active) { false }
        let(:socket_active) { false }

        let(:action) { :start }

        it "does not register any error for the action" do
          system_service.save

          expect(system_service.errors).to_not have_key(:active)
        end
      end

      context "and the action cannot be performed" do
        before do
          allow(service).to receive(:start).and_return(false)
          allow(socket).to receive(:start).and_return(false)
        end

        let(:service_active) { false }
        let(:socket_active) { false }

        let(:action) { :start }

        it "registers an error for the action" do
          system_service.save

          expect(system_service.errors).to have_key(:active)
        end
      end
    end
  end

  describe "#reset" do
    before do
      system_service.start_mode = :on_demand
      system_service.stop
    end

    it "clears all cached changes" do
      expect(system_service.changed_value?(:start_mode)).to eq(true)
      expect(system_service.changed_value?(:active)).to eq(true)

      system_service.reset

      expect(system_service.changed_value?(:start_mode)).to eq(false)
      expect(system_service.changed_value?(:active)).to eq(false)
    end
  end

  describe "#refresh" do
    before do
      allow(service).to receive(:refresh!)
    end

    it "refreshes the service" do
      expect(service).to receive(:refresh!).and_return(true)

      system_service.refresh
    end
  end

  describe "#changed?" do
    context "when some change was made" do
      before do
        system_service.stop
      end

      it "returns true" do
        expect(system_service.changed?).to eq(true)
      end
    end

    context "when no changes were made" do
      it "returns false" do
        expect(system_service.changed?).to eq(false)
      end
    end
  end

  describe "#changed_value?" do
    context "when no value has been changed" do
      it "returns true" do
        expect(system_service.changed_value?(:active)).to eq(false)
      end
    end

    context "when some value has been changed" do
      before do
        system_service.stop
      end

      it "returns true" do
        expect(system_service.changed_value?(:active)).to eq(true)
      end
    end
  end
end
