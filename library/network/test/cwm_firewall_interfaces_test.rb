#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "CWMFirewallInterfaces"
Yast.import "NetworkInterfaces"
Yast.import "Mode"
Yast.import "UI"

describe Yast::CWMFirewallInterfaces do
  subject { Yast::CWMFirewallInterfaces }
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:api) { instance_double("Y2Firewall::Firewalld::Api") }

  before do
    allow(api).to receive(:service_supported?)
    allow(firewalld).to receive(:api).and_return(api)
  end

  describe "#CreateOpenFirewallWidget" do
    let(:widget_settings) { { "services" => [] } }
    let(:installed) { true }

    before do
      allow(firewalld).to receive(:installed?).and_return(installed)
    end

    context "when firewalld is not installed" do
      let(:installed) { false }
      let(:widget_settings) { { "services" => ["apache2"] } }

      it "returns a hash with only the 'widget', 'custom_widget' and 'help' keys" do
        ret = subject.CreateOpenFirewallWidget(widget_settings)
        expect(ret.keys.sort).to eq(["widget", "custom_widget", "help"].sort)
      end

      it "returns a widget alerting of it as the 'custom_widget'" do
        expect(subject).to receive(:not_installed_widget)
          .and_return("not_installed_widget")
        expect(subject.CreateOpenFirewallWidget(widget_settings)["custom_widget"])
          .to eq("not_installed_widget")
      end
    end

    context "when the widget settings does not contain any service" do
      it "returns a hash with only the 'widget', 'custom_widget' and 'help' keys" do
        ret = subject.CreateOpenFirewallWidget(widget_settings)
        expect(ret.keys.sort).to eq(["widget", "custom_widget", "help"].sort)
      end

      it "returns an empty VBox() as the 'custom_widget'" do
        expect(subject.CreateOpenFirewallWidget(widget_settings)["custom_widget"]).to eq(VBox())
      end
    end

    context "when the widget settings does not contain any service" do
      let(:widget_settings) { { "services" => ["service"] } }

      before do
        allow(api).to receive(:service_supported?).with("service").and_return(false)
      end

      it "returns a hash with only the 'widget', 'custom_widget' and 'help' keys" do
        allow(subject).to receive(:services_not_defined_widget).with(["service"])
          .and_return(Frame("unsupported_services_summary"))

        ret = subject.CreateOpenFirewallWidget(widget_settings)

        expect(ret.keys.sort).to eq(["widget", "custom_widget", "help"].sort)
      end

      it "returns a summary with the unavailable services as the 'custom_widget'" do
        expect(subject).to receive(:services_not_defined_widget).with(["service"])
          .and_return(Frame("unsupported_services_summary"))
        expect(api).to receive(:service_supported?).with("service").and_return(false)

        ret = subject.CreateOpenFirewallWidget(widget_settings)

        expect(ret["custom_widget"]).to eq(Frame("unsupported_services_summary"))
      end
    end
  end

  describe "#OpenFirewallInit" do
    let(:open_firewall_widget) { false }
    let(:widget_settings) { { "services" => ["apache"] } }
    let(:allowed_interfaces) { ["eth0"] }
    let(:all_interfaces) { ["eth0", "eth1"] }
    let(:firewalld_enabled?) { true }

    before do
      allow(Yast::UI).to receive(:WidgetExists).with(Id("_cwm_open_firewall"))
        .and_return(open_firewall_widget)
      allow(subject).to receive(:InitAllInterfacesList)
      allow(subject).to receive(:InitAllowedInterfaces)
      allow(subject).to receive(:UpdateFirewallStatus)
      allow(subject).to receive(:EnableOrDisableFirewallDetails)
      allow(subject).to receive(:allowed_interfaces).and_return(allowed_interfaces)
      allow(subject).to receive(:all_interfaces).and_return(all_interfaces)
      allow(Yast::UI).to receive(:ChangeWidget)
      allow_any_instance_of(Y2Firewall::Firewalld)
        .to receive(:enabled?).and_return(firewalld_enabled?)
    end

    context "when the open firewall widget does not exist" do
      it "return nil" do
        subject.OpenFirewallInit(widget_settings, "")
      end
    end

    context "when the open firewall widget exist" do
      let(:open_firewall_widget) { true }

      it "initializes the list of network interfaces" do
        expect(subject).to receive(:InitAllInterfacesList)
        subject.OpenFirewallInit(widget_settings, "")
      end

      it "initializes the list of allowed interfaces" do
        expect(subject).to receive(:InitAllowedInterfaces)
        subject.OpenFirewallInit(widget_settings, "")
      end

      it "updates the firewalld status label" do
        expect(subject).to receive(:UpdateFirewallStatus)
        subject.OpenFirewallInit(widget_settings, "")
      end

      it "enables or disables the firewall details button according to the settings" do
        expect(subject).to receive(:EnableOrDisableFirewallDetails)
        subject.OpenFirewallInit(widget_settings, "")
      end

      context "and firewalld is enabled" do
        context "but there are no network interfaces in the system" do
          let(:all_interfaces) { [] }

          it "disables the open port checkbox" do
            expect(Yast::UI).to receive(:ChangeWidget)
              .with(Id("_cwm_open_firewall"), :Enabled, false)

            subject.OpenFirewallInit(widget_settings, "")
          end

          it "sets the open port checkbox as unchecked" do
            expect(Yast::UI).to receive(:ChangeWidget)
              .with(Id("_cwm_open_firewall"), :Value, false)

            subject.OpenFirewallInit(widget_settings, "")
          end
        end
      end

      context "and firewalld is disabled" do
        let(:firewalld_enabled?) { false }

        it "disables the open port checkbox" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id("_cwm_open_firewall"), :Enabled, false)

          subject.OpenFirewallInit(widget_settings, "")
        end

        it "sets the open port checkbox as unchecked" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id("_cwm_open_firewall"), :Value, false)

          subject.OpenFirewallInit(widget_settings, "")
        end
      end
    end

  end

  describe "#InitAllInterfacesList" do
    let(:mode) { "normal" }

    before do
      allow(Yast::Mode).to receive(:mode).and_return(mode)
    end
    context "when called in :installation, :update or :config Mode" do
      let(:mode) { "update" }

      it "does not read network interfaces config" do
        allow(Yast::Mode).to receive(:config).and_return(true)
        expect(Yast::NetworkInterfaces).to_not receive(:Read)

        subject.InitAllInterfacesList
      end
    end

    context "in other modes" do
      it "reads the network interfaces configuration" do
        expect(Yast::NetworkInterfaces).to receive(:Read)

        subject.InitAllInterfacesList
      end
    end
  end

  describe "#Selected2Opened" do
    let(:known_interfaces) do
      [
        { "id" => "eth0", "name" => "Ethernet 1", "zone" => "external" },
        { "id" => "eth1", "name" => "Ethernet 2", "zone" => "public" },
        { "id" => "eth2", "name" => "Ethernet 3", "zone" => "dmz" }
      ]
    end

    before do
      allow(subject).to receive(:known_interfaces).and_return(known_interfaces)
    end

    context "given a list of selected interfaces" do
      let(:zone) do
        instance_double("Y2Firewall::Firewalld::Zone", interfaces: ["eth0", "eth1"], name: "public")
      end

      before do
        allow(subject).to receive(:interface_zone).with("eth0").and_return("public")
        allow(firewalld).to receive(:find_zone).and_return(zone)
      end

      it "returns all the interfaces that belongs to same zone of the given interfaces" do
        expect(subject.Selected2Opened(["eth0"], false)).to eq(["eth0", "eth1"])
      end
    end
  end

  describe "#StoreAllowedInterfaces" do
    let(:known_interfaces) do
      [
        { "id" => "eth0", "name" => "Ethernet 1", "zone" => "external" },
        { "id" => "eth1", "name" => "Ethernet 2", "zone" => "public" },
        { "id" => "eth2", "name" => "Ethernet 3", "zone" => nil }
      ]
    end

    let(:external_zone) do
      instance_double("Y2Firewall::Firewalld::Zone", name: "external",
                      interfaces: ["eth0"], services: [])
    end

    let(:public_zone) do
      instance_double("Y2Firewall::Firewalld::Zone", name: "public",
                      interfaces: ["eth1"], services: ["dns"])
    end

    let(:zones) { [external_zone, public_zone] }

    before do
      expect(subject).to receive(:known_interfaces).and_return(known_interfaces)
      expect(subject).to receive(:allowed_interfaces).and_return(["eth0", "eth1"])
      allow(firewalld).to receive(:zones).and_return(zones)
      allow(subject).to receive(:default_zone).and_return(public_zone)
      allow(subject).to receive(:configuration_changed).and_return(true)
      allow(subject).to receive(:allowed_interfaces).and_return(["eth0", "eth1", "eth2"])
    end

    context "given a list of services" do
      context "and having set the list of allowed interfaces" do
        it "enables each service in the zones with allowed interfaces" do
          expect(public_zone).to_not receive(:add_service)
          expect(public_zone).to_not receive(:remove_service)
          expect(external_zone).to receive(:add_service).with("dns")

          subject.StoreAllowedInterfaces(["dns"])
        end
      end
    end
  end
end
