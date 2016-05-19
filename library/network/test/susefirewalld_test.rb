#!/usr/bin/env rspec

require_relative "test_helper"
require "network/firewalld"

Yast.import "Mode"
Yast.import "PackageSystem"
Yast.import "Pkg"
Yast.import "SuSEFirewall"
Yast.import "SuSEFirewallServices"
Yast.import "Stage"

def reset_FirewallDIsInstalled_cache
  FakeFirewallD.needed_packages_installed = nil
end

# A few notes: FirewallD requires a running backend before it attempts to make
# any firewall changes. But since this is a testsuite, we shouldn't mess with
# the running system so we need to mock a lot of the API functions and trust we
# the API does its job. However, you can set the 'need_API_mock' variable to
# false to bypass mocking and use the real API. This will break your firewall
# etc so make sure you understand the risks. Moreover, mocking the API has the
# advantage of being able to run this testsuite even when SF2 is running!
need_API_mock = true

# Re-instansiate our objects
FakeFirewallD = Yast::FirewallClass.create(:fwd)

describe FakeFirewallD do

  describe "#SuSEFirewallIsInstalled" do
    before do
      reset_FirewallDIsInstalled_cache
    end

    context "while in inst-sys" do
      it "returns whether FirewallD is selected for installation or already installed" do
        expect(Yast::Stage).to receive(:stage).and_return("initial").at_least(:once)

        # Value is not cached
        expect(Yast::Pkg).to receive(:IsSelected).and_return(true, false, false).exactly(3).times
        # Fallback: if not selected, checks whether the package is installed
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        # Selected
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Not selected and not installed
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        # Not selected, but installed
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end

    context "while on a running system (normal configuration)" do
      it "returns whether FirewallD was or could have been installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("normal").at_least(:once)

        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true, false)
        # Start fresh
        reset_FirewallDIsInstalled_cache
        # Install it
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Start fresh
        reset_FirewallDIsInstalled_cache
        # Do not install it
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
      end
    end

    context "while in AutoYast config" do
      it "returns whether FirewallD is installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("autoinst_config").at_least(:once)

        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true)

        # Start fresh
        reset_FirewallDIsInstalled_cache
        # Do not istall it
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        # Start fresh
        reset_FirewallDIsInstalled_cache
        # Install it
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end
  end

  describe "#FirewallD" do

    before(:example) do
      # Need a consistent view of the system interfaces.
      allow(Yast::NetworkInterfaces).to receive(:List) { ["eth0", "eth1", "eth2", "eth3", "eth4", "lo"] }
      if need_API_mock
        # Do not read the system rules. This also prevents backend from starting
        allow(subject).to receive(:Read)
        # Do not attempt to write anything
        allow(subject).to receive(:Write)
        # Fake a running backend
        allow(subject).to receive(:IsStarted) { true }
        allow(subject).to receive(:StartServices)
        # Add some well-known services that we will use throughout this
        # testsuite
        allow(subject.api).to receive(:services)
          .and_return(["dns", "ftp", "ldap", "ntp", "ssh"])
        allow(subject.api).to receive(:service_supported?) { false }
        allow(subject.api).to receive(:service_supported?).with("dns") { true }
        allow(subject.api).to receive(:service_supported?).with("ftp") { true }
        allow(subject.api).to receive(:service_supported?).with("ldap") { true }
        allow(subject.api).to receive(:service_supported?).with("ntp") { true }
        allow(subject.api).to receive(:service_supported?).with("ssh") { true }
        allow(subject.api).to receive(:service_supported?).with("telnet") { true }
        # Remember. Yast::SuSEFirewallServices may still think that the
        # running backend is SF2 so fake some methods.
        # We use the ssh, ntp, ftp, ldap, telnet, dns so support them
        allow(Yast::SuSEFirewallServices).to receive(:GetSupportedServices)
          .and_return("dns"    => "The dns",
                      "ftp"    => "The ftp",
                      "ldap"   => "The ldap",
                      "ntp"    => "The ntp",
                      "ssh"    => "The ssh",
                      "telnet" => "The telnet")
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("ftp")
          .and_return("tcp_ports" => ["21"])
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("dns")
          .and_return("tcp_ports" => ["53"], "udp_ports" => ["53"])
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("ldap")
          .and_return("tcp_ports" => ["389"])
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("ntp")
          .and_return("tcp_ports" => ["123"])
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("ssh")
          .and_return("tcp_ports" => ["22"])
        allow(Yast::SuSEFirewallServices).to receive(:service_details).with("telnet")
          .and_return("tcp_ports" => ["23"])
      end
    end

    GOOD_FAKE_FIREWALLD_CONFIG = {
      "logging"         => "off",
      "start_firewall"  => true,
      "enable_firewall" => true,
      "external"        => {
        masquerade: true,
        interfaces: ["eth0", "eth1"],
        services:   ["ssh"],
        ports:      ["999/tcp", "1010/udp"]
      },
      "public"          => {
        masquerade: false,
        interfaces: ["eth2"],
        services:   ["dns"],
        protocols:  ["ah"]
      }
    }

    BAD_FAKE_FIREWALLD_CONFIG = {
      "dmz"     => {
        invalid_setting: true
      },
      "foozone" => {
        masquerade: true,
        services:   ["foobar"],
        interfaces: ["eth3"]
      }
    }
    FULL_FAKE_FIREWALLD_CONFIG = GOOD_FAKE_FIREWALLD_CONFIG.merge(BAD_FAKE_FIREWALLD_CONFIG)

    context "when verifying its basic configuration" do

      it "has 'firewalld' in the FIREWALL_PACKAGE variable" do
        expect(subject.FIREWALL_PACKAGE).to eq("firewalld")
      end
      it "has its API backend set" do
        expect(subject.api).not_to be nil
      end
    end

    context "given a known configuration" do
      it "can import it and export it" do
        expect(subject.Import(FULL_FAKE_FIREWALLD_CONFIG)).to be nil
        good_config = Yast.deep_copy(GOOD_FAKE_FIREWALLD_CONFIG)
        GOOD_FAKE_FIREWALLD_CONFIG.keys.each do |key|
          next unless subject.GetKnownFirewallZones().include?(key)
          good_config[key] = Yast::SuSEFirewalldClass::EMPTY_ZONE.merge(good_config[key])
          # When importing configuration we consider all zone attributes as
          # dirty
          good_config[key][:modified] = [:interfaces, :masquerade, :ports, :protocols, :services]
        end
        expect(subject.Export).to include(good_config)
      end

      it "it does not propagate invalid settings to internal data structures" do
        expect(subject.Export).not_to include(BAD_FAKE_FIREWALLD_CONFIG)
      end

      it "does not support the IsAnyNetworkInterfaceSupported method" do
        expect(subject.IsAnyNetworkInterfaceSupported).to be false
      end

      it "does not support the GetProtectFromInternalZone method" do
        expect(subject.IsAnyNetworkInterfaceSupported).to be false
      end

      it "the 'public' zone is a known one" do
        expect(subject.IsKnownZone("public")).to be true
        known_zones = subject.GetKnownFirewallZones
        expect(known_zones.include?("public")).to be true
      end

      it "the '__foobarme__' zone is not a known one" do
        expect(subject.IsKnownZone("__foobarme__")).to be false
        known_zones = subject.GetKnownFirewallZones
        expect(known_zones.include?("__foobarme__")).to be false
      end

      it "knows the SF2 EXT zone is the 'external' one in FirewallD" do
        expect(subject.sf2_to_firewalld_zone("EXT")).to eq("external")
      end

      it "knows that 'dmz' means 'Demilitarized Zone'" do
        expect(subject.GetZoneFullName("dmz")).to eq("Demilitarized Zone")
      end

      it "it does not propagate invalid settings to internal data structures" do
        expect(subject.Export).not_to include(BAD_FAKE_FIREWALLD_CONFIG)
      end

      it "can set the masquerade to 'public' zone" do
        expect(subject.SetMasquerade(true, "public")).to be nil
        expect(subject.GetMasquerade("public")).to be true
      end

      it "can disable the masquerade to 'dmz' zone" do
        expect(subject.SetMasquerade(false, "dmz")).to be nil
        expect(subject.GetMasquerade("dmz")).to be false
      end

      it "can enable and disable masquerade on every zone" do
        expect(subject.SetMasquerade(true)).to be nil
        expect(subject.GetMasquerade).to be true
        expect(subject.SetMasquerade(false)).to be nil
        expect(subject.GetMasquerade).to be false
      end

      it "can retrieve existing services in a zone" do
        expect(subject.GetAllowedServicesForZoneProto("external", "tcp")).to eq(["999", "ssh"])
        expect(subject.GetAllowedServicesForZoneProto("external", "udp")).to eq(["1010"])
      end

      it "can set the 'ssh' service to an 'external' zone interface" do
        expect(subject.SetServices(["ssh"], ["eth0"], true)).to be nil
        # A bit complex because the return value is of the form
        # ["ssh" => { zone1 => status, zone2 => status etc }]
        expect(subject.GetServices(["ssh"])["ssh"]).to include("external" => true)
        expect(subject.IsServiceSupportedInZone("ssh", "external")).to be true
        expect(subject.GetServicesInZones(["ssh"])["ssh"]).to include("eth0" => true, "eth1" => true)
        expect(subject.GetAllowedServicesForZoneProto("external", "tcp")).to eq(["999", "ssh"])
      end

      it "can set the 'service:ntp' to an 'external' zone interface" do
        expect(subject.SetServices(["service:ntp"], ["eth1"], true)).to be nil
        expect(subject.GetServices(["service:ntp"])["service:ntp"]).to include("external" => true)
        expect(subject.IsServiceSupportedInZone("service:ntp", "external")).to be true
        expect(subject.GetServicesInZones(["service:ntp"])["service:ntp"]).to include("eth0" => true, "eth1" => true)
      end

      it "can set multiple services to an 'external' zone interface" do
        expect(subject.SetServices(["service:ftp", "ldap"], ["eth0", "eth1"], true)).to be nil
        expect(subject.GetServices(["service:ftp"])["service:ftp"]).to include("external" => true)
        expect(subject.GetServices(["ldap"])["ldap"]).to include("external" => true)
        expect(subject.GetServicesInZones(["service:ftp"])["service:ftp"]).to \
          eq("eth0" => true, "eth1" => true, "eth2" => false)
      end

      it "can remove the 'service:ntp' from an 'external' zone interface" do
        expect(subject.SetServices(["service:ntp"], ["eth1"], false)).to be nil
        expect(subject.GetServices(["service:ntp"])["service:ntp"]).to include("external" => false)
        expect(subject.IsServiceSupportedInZone("service:ntp", "external")).to be false
        expect(subject.GetServicesInZones(["service:ntp"])["service:ntp"]).to \
          eq("eth0" => false, "eth1" => false, "eth2" => false)
      end

      it "can add the 'service:ntp' to the 'external' zone" do
        expect(subject.SetServicesForZones(["service:ntp"], ["external"], true)).to be nil
        expect(subject.GetServicesInZones(["service:ntp"])["service:ntp"]).to \
          eq("eth0" => true, "eth1" => true, "eth2" => false)
      end

      it "can use {Add,Remove}Service methods to manage services" do
        expect(subject.AddService("telnet", "TCP", "external")).to be true
        expect(subject.HaveService("telnet", "TCP", "external")).to be true
        expect(subject.RemoveService("telnet", "TCP", "external")).to be true
        expect(subject.HaveService("telnet", "TCP", "external")).to be false
      end

      it "refuses to set service to a non-existing interface" do
        expect(subject.SetServices(["dns"], ["ethfoobar"], true)).to be nil
      end
      it "refuses to set an invalid service to a zone" do
        # mock a running backend
        expect { subject.SetServices(["foobar"], ["eth0"], true) }.to raise_exception(
          Yast::SuSEFirewalServiceNotFound, /Service with name/)
      end

      it "knows about all the new TCP services a zone" do
        # This should not contain ssh, ftp and ldap since these are
        # known services
        expect(subject.GetAdditionalServices("tcp", "external").sort).to \
          eq(["999"].sort)
      end

      it "knows about the IP protocols in a zone" do
        expect(subject.GetAdditionalServices("ip", "public")).to eq(["ah"])
      end

      it "adds new ports/protocols services in a zone" do
        expect(subject.SetAdditionalServices("tcp", "public", ["1234"])).to be nil
        # DNS is a known service so it should not make it to the list
        # Ditto for the rest of these examples
        expect(subject.GetAdditionalServices("tcp", "public").sort).to \
          eq(["1234"].sort)
      end
      it "can set new ports/protocols overwriting the existing ones" do
        expect(subject.SetAdditionalServices("tcp", "public", ["5678"])).to be nil
        expect(subject.GetAdditionalServices("tcp", "public").sort).to \
          eq(["5678"])
      end
      it "can set ranges of ports" do
        expect(subject.SetAdditionalServices("tcp", "public", ["1234-5678"])).to be nil
        expect(subject.GetAdditionalServices("tcp", "public").sort).to \
          eq(["1234-5678"].sort)
      end
      it "can set a UDP port without losing TCP port states" do
        expect(subject.SetAdditionalServices("udp", "public", ["53"])).to be nil
        expect(subject.GetAdditionalServices("udp", "public").sort).to \
          eq(["53"].sort)
        # Here we check that UDP additions do not overwrite TCP and vice
        # versa
        expect(subject.SetAdditionalServices("tcp", "public", ["1234-5678"])).to be nil
        expect(subject.GetAdditionalServices("tcp", "public").sort).to \
          eq(["1234-5678"].sort)
      end

      it "add SF2 style port ranges in a zone" do
        expect(subject.SetAdditionalServices("tcp", "public", ["1234:5678"])).to be nil
        expect(subject.GetAdditionalServices("tcp", "public").sort).to \
          eq(["1234-5678"].sort)
      end

      it "adds an existing interface to zone" do
        expect(subject.AddInterfaceIntoZone("eth4", "external")).to be nil
        expect(subject.GetInterfacesInZone("external")). to eq(["eth0", "eth1", "eth4"])
      end

      it "adds an existing interface to zone and removes it from the other zones" do
        expect(subject.AddInterfaceIntoZone("eth2", "dmz")).to be nil
        expect(subject.GetInterfacesInZone("dmz")).to eq(["eth2"])
        expect(subject.GetInterfacesInZone("public")).to eq([])
      end

      it "can remove an existing interface from zone" do
        expect(subject.RemoveInterfaceFromZone("eth2", "dmz")).to be nil
        expect(subject.GetInterfacesInZone("dmz")).to eq([])
      end

      it "adds a special interfaces to zone" do
        expect(subject.AddSpecialInterfaceIntoZone("tun+", "dmz")).to be nil
        expect(subject.GetSpecialInterfacesInZone("dmz")).to include("tun+")
      end

      it "refuses to add interfaces to a non-existing zone" do
        expect(subject.AddInterfaceIntoZone("eth2", "nogoodzone")).to be nil
        expect(subject.GetInterfacesInZone("nogoodzone")).to eq([])
      end

      it "can understand SF2-like logging" do
        expect(subject.SetLoggingSettings("ACCEPT", "__DOES_NOT_MATTER__")).to be nil
        expect(subject.GetLoggingSettings("ACCEPT")).to be false
        expect(subject.SetLoggingSettings("DROP", "CRIT")).to be nil
        expect(subject.GetLoggingSettings("DROP")).to eq("CRIT")
        expect(subject.SetLoggingSettings("DROP", "NONE")).to be nil
        expect(subject.GetLoggingSettings("DROP")).to eq("NONE")
        expect(subject.SetLoggingSettings("DROP", "ALL")).to be nil
        expect(subject.GetLoggingSettings("DROP")).to eq("ALL")
      end

      it "can enable broadcast logging" do
        expect(subject.SetIgnoreLoggingBroadcast(nil, "yes")).to be nil
        expect(subject.GetIgnoreLoggingBroadcast(nil)).to eq("yes")
      end
    end
  end
end
