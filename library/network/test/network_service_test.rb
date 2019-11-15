#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "NetworkService"

describe Yast::NetworkService do
  context "smoke test" do
    describe "#is_network_manager" do
      it "does not crash" do
        expect { Yast::NetworkService.is_network_manager }.not_to raise_error
      end
    end

    describe "#is_wicked" do
      it "does not crash" do
        expect { Yast::NetworkService.is_wicked }.not_to raise_error
      end
    end

    describe "#is_netconfig" do
      it "does not crash" do
        expect { Yast::NetworkService.is_netconfig }.not_to raise_error
      end
    end
  end

  describe "#RunSystemCtl" do
    it "shellescape properly all arguments" do
      expect(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        "/usr/bin/systemctl --force enable wicked.service",
        "TERM" => "raw")

      subject.RunSystemCtl("wicked", "enable", force: true)

      expect(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        "/usr/bin/systemctl  disable\\ \\|\\ evil wicked.service",
        "TERM" => "raw")

      subject.RunSystemCtl("wicked", "disable | evil")
    end

    it "raises an exception when no service name is provided" do
      expect { Yast::NetworkService.RunSystemCtl(nil, "enable") }.to raise_error
    end
  end

  describe "#EnableDisableNow" do
    subject { Yast::NetworkService }

    before(:each) do
      expect(subject).to receive(:Modified).and_return(true)
    end

    context "When changing running service" do
      before(:each) do
        allow(subject).to receive(:current_name).and_return(:netconfig)

        # using anything instead of exact service name because of some magic in identifying the service in the system
        expect(subject).to receive(:RunSystemCtl).with(anything, /stop|kill/)
        expect(subject).to receive(:RunSystemCtl).with("network", "disable")
      end

      it "disables old service and enables new one" do
        allow(subject).to receive(:cached_name).and_return(:wicked)

        expect(subject).to receive(:RunSystemCtl).with("wicked", "enable", any_args)

        subject.EnableDisableNow
      end

      it "only disables old service when no network service was requested" do
        allow(subject).to receive(:cached_name).and_return(nil)

        expect(subject).not_to receive(:RunSystemCtl).with("wicked", "enable", any_args)

        subject.EnableDisableNow
      end
    end

    context "When activating a service if none is running" do
      before(:each) do
        allow(subject).to receive(:current_name).and_return(nil)
        allow(subject).to receive(:cached_name).and_return(:wicked)
      end

      it "activates new service" do
        expect(subject).to receive(:RunSystemCtl).with("wicked", "enable", any_args)

        subject.EnableDisableNow
      end
    end
  end

  describe "#backend_in_use" do
    let(:initial_stage) { true }
    let(:systemd_running) { true }
    let(:service_name) { "NetworkManager" }
    let(:service) { instance_double("Yast2::Systemd::Service", name: service_name) }
    before do
      allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
      allow(Yast::Systemd).to receive(:Running).and_return(systemd_running)
      allow(Yast2::Systemd::Service).to receive(:find).and_return(service)
    end

    context "when running on the initial Stage" do
      context "and systemd is not running" do
        let(:systemd_running) { false }

        it "returns the default backend symbol" do
          expect(subject.backend_in_use).to eq(Yast::NetworkServiceClass::DEFAULT_BACKEND)
        end
      end

      context "and systemd is running" do
        context "and wicked is linked to the network service" do
          let(:service_name) { "wicked" }

          it "returns :wicked" do
            expect(subject.backend_in_use).to eq(:wicked)
          end
        end

        context "and NetworkManager is linked to the network service" do
          it "returns :network_manager" do
            expect(subject.backend_in_use).to eq(:network_manager)
          end
        end

        context "and no service is linked to the network service" do
          let(:service) { nil }

          it "returns nil" do
            expect(subject.backend_in_use).to be_nil
          end
        end
      end
    end
  end

  describe "#Read" do
    before do
      allow(subject).to receive(:backend_in_use).and_return(:wicked)
      subject.reset!
    end

    it "reads the current state and caches it" do
      expect(subject).to receive(:backend_in_use).once.and_return(:wicked)
      expect(subject.wicked?).to eq(true)
      expect(subject.wicked?).to eq(true)
    end
  end
end
