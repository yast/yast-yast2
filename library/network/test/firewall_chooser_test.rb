#!/usr/bin/env rspec

require_relative "test_helper"
require "network/firewall_chooser"

describe Yast::FirewallChooser do
  describe ".installed_backeds" do

  end

  describe ".choose" do
    context "when :sf2 is specified" do
      it "returns a SuSEFirewall2Class object" do
        expect(described_class.choose(:sf2)).to be_a(Yast::SuSEFirewall2Class)
      end
    end

    context "when :fwd is specified" do
      it "returns a SuSEFirewalldClass object" do
        expect(described_class.choose(:fwd)).to be_a(Yast::SuSEFirewalldClass)
      end
    end

    context "when no backend is specified" do
      it "returns and object of the detected one" do
        expect(described_class).to receive(:detect).and_return(:sf2, :fwd)
        expect(described_class.choose).to be_a(Yast::SuSEFirewall2Class)
        expect(described_class.choose).to be_a(Yast::SuSEFirewalldClass)
      end
    end
  end

  describe ".detect" do
    let(:fwd_installed) { false }
    let(:fwd_enabled) { false }
    let(:fwd_running) { false }
    let(:sf2_installed) { false }
    let(:sf2_enabled) { false }
    let(:sf2_running) { false }

    before do
      allow(Yast::Mode).to receive(:testsuite).and_return(false)
      allow(Yast::Service).to receive(:Enabled).with("firewalld").and_return(fwd_enabled)
      allow(Yast::Service).to receive(:Enabled).with("SuSEfirewall2").and_return(sf2_enabled)
      allow(Yast::Service).to receive(:Active).with("firewalld").and_return(fwd_running)
      allow(Yast::Service).to receive(:Active).with("SuSEfirewall2").and_return(sf2_running)
      allow(Yast::PackageSystem).to receive(:Installed).with("firewalld").and_return(fwd_installed)
      allow(Yast::PackageSystem).to receive(:Installed).with("SuSEfirewall2").and_return(sf2_installed)
    end

    context "when neither firewalld nor SuSEfirewall2 are running" do
      it "returns :sf2 as the fallback" do
        expect(Yast::FirewallChooser.detect).to eql(:sf2)
      end
    end

    context "when only firewalld is installed" do
      let(:fwd_installed) { true }
      it "returns :fwd" do
        expect(Yast::FirewallChooser.detect).to eql(:fwd)
      end
    end

    context "when only SuSEFirewall2 is installed" do
      let(:sf2_installed) { true }
      it "returns :sf2" do
        expect(Yast::FirewallChooser.detect).to eql(:sf2)
      end
    end

    context "when both are installed" do
      let(:sf2_installed) { true }
      let(:fwd_installed) { true }

      context "and neither firewalld nor SuSEfirewall2 are running" do
        context "and no one is enabled" do
          it "returns :sf2 as the fallback" do
            expect(Yast::FirewallChooser.detect).to eql(:sf2)
          end
        end

        context "and both are enabled" do
          let(:fwd_enabled) { true }
          let(:sf2_enabled) { true }

          it "returns :sf2" do
            expect(Yast::FirewallChooser.detect).to eql(:sf2)
          end
        end

        context "and firewalld is enabled" do
          let(:fwd_enabled) { true }

          it "returns :fwd" do
            expect(Yast::FirewallChooser.detect).to eql(:fwd)
          end
        end

        context "and SuSEfirewall2 is enabled" do
          let(:sf2_enabled) { true }

          it "returns :sf2" do
            expect(Yast::FirewallChooser.detect).to eql(:sf2)
          end
        end
      end

      context "and firewalld is running" do
        let(:fwd_running) { true }
        it "returns :fwd" do
          expect(Yast::FirewallChooser.detect).to eql(:fwd)
        end
      end

      context "and SuSEFirewall2 is running" do
        let(:sf2_installed) { true }
        let(:fwd_installed) { true }
        let(:sf2_running) { true }
        it "returns :sf2" do
          expect(Yast::FirewallChooser.detect).to eql(:sf2)
        end
      end

      context "and both are running" do
        let(:sf2_installed) { true }
        let(:fwd_installed) { true }
        let(:sf2_running) { true }
        let(:fwd_running) { true }

        it "raises and exception" do
          expect { Yast::FirewallChooser.detect }
            .to raise_error(Yast::SuSEFirewallMultipleBackends)
        end
      end
    end
  end
end
