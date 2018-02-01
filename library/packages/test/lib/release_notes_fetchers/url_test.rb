#!/usr/bin/env rspec

require_relative "../../test_helper"
require "y2packager/release_notes_fetchers/url"
require "y2packager/product"

describe Y2Packager::ReleaseNotesFetchers::Url do
  subject(:fetcher) { described_class.new(product) }

  let(:product) { instance_double(Y2Packager::Product, name: "dummy") }
  let(:relnotes_url) { "http://doc.opensuse.org/openSUSE/release-notes-openSUSE.rpm" }
  let(:content) { "Release Notes\n" }
  let(:language) { double("Yast::Language", language: "de_DE") }
  let(:curl_retcode) { 0 }

  let(:relnotes_tmpfile) do
    instance_double(Tempfile, path: "/tmp/relnotes", close: nil, unlink: nil)
  end

  let(:index_tmpfile) do
    instance_double(Tempfile, path: "/tmp/directory.yast", close: nil, unlink: nil)
  end

  let(:proxy_enabled) { false }
  let(:proxy) { double("Yast::Proxy", Read: nil, enabled: proxy_enabled) }

  let(:user_lang) { "de_DE" }
  let(:format) { :txt }
  let(:fallback_lang) { "en" }
  let(:prefs) { Y2Packager::ReleaseNotesContentPrefs.new(user_lang, fallback_lang, format) }

  before do
    allow(Yast::Pkg).to receive(:ResolvableProperties)
      .with(product.name, :product, "").and_return(["relnotes_url" => relnotes_url])
    allow(File).to receive(:read).with(/relnotes/).and_return(content)
    allow(Yast::SCR).to receive(:Execute)
      .with(Yast::Path.new(".target.bash"), /curl.*directory.yast/)
      .and_return(1)
    allow(Yast::SCR).to receive(:Execute)
      .with(Yast::Path.new(".target.bash"), /curl.*RELEASE-NOTES/)
      .and_return(curl_retcode)
    allow(Tempfile).to receive(:new).with(/relnotes/).and_return(relnotes_tmpfile)
    allow(Tempfile).to receive(:new).with(/directory.yast/).and_return(index_tmpfile)
    described_class.clear_blacklist
    described_class.enable!

    stub_const("Yast::Language", language)
    stub_const("Yast::Proxy", proxy)
  end

  describe "#release_notes" do
    it "returns release notes" do
      cmd = %r{curl.*'http://doc.opensuse.org/openSUSE/RELEASE-NOTES.de_DE.txt'}
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash"), cmd)
        .and_return(0)
      expect(File).to receive(:read).with(/relnotes/).and_return(content)
      rn = fetcher.release_notes(prefs)

      expect(rn.product_name).to eq("dummy")
      expect(rn.content).to eq(content)
      expect(rn.user_lang).to eq("de_DE")
      expect(rn.format).to eq(:txt)
      expect(rn.version).to eq(:latest)
    end

    it "uses cURL to download release notes" do
      cmd = "/usr/bin/curl --location --verbose --fail --max-time 300 --connect-timeout 15   " \
        "'http://doc.opensuse.org/openSUSE/RELEASE-NOTES.de_DE.txt' --output '/tmp/relnotes' " \
        "> '/var/log/YaST2/curl_log' 2>&1"

      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash"), cmd)
      fetcher.release_notes(prefs)
    end

    context "when release notes are not found for the given language" do
      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.#{user_lang}.txt/)
          .and_return(1)
      end

      it "returns release notes for the generic language" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.de.txt/)
          .and_return(0)
        fetcher.release_notes(prefs)
      end

      context "and are not found for the generic language" do
        before do
          allow(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.de.txt/)
            .and_return(1)
        end

        it "falls back to 'en'" do
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.en.txt/)
            .and_return(0)
          fetcher.release_notes(prefs)
        end
      end

      context "and the default language is 'en_*'" do
        let(:user_lang) { "en_US" }

        # bsc#1015794
        it "tries only 1 time with 'en'" do
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.en.txt/)
            .once.and_return(1)
          fetcher.release_notes(prefs)
        end
      end
    end

    context "when release notes index exists" do
      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl.*directory.yast/)
          .and_return(0)
        allow(File).to receive(:read).with(/directory.yast/)
          .and_return(release_notes_index)
      end

      context "and wanted release notes are registered in that file" do
        let(:release_notes_index) do
          "RELEASE-NOTES.de_DE.txt\nRELEASE-NOTES.en_US.txt"
        end

        it "tries to download release notes" do
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.de_DE.txt/)
            .and_return(0)
          fetcher.release_notes(prefs)
        end
      end

      context "and wanted release notes are not registered in that file" do
        let(:release_notes_index) do
          "RELEASE-NOTES.en_US.txt"
        end

        it "does not try to download release notes" do
          expect(Yast::SCR).to_not receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /RELEASE-NOTES.de_DE.txt/)
          fetcher.release_notes(prefs)
        end
      end
    end

    context "when release notes are not found" do
      let(:curl_retcode) { 1 }

      it "blacklists the URL" do
        expect(described_class).to receive(:add_to_blacklist).with(relnotes_url)
        fetcher.release_notes(prefs)
      end
    end

    context "when a connection problem happens" do
      let(:curl_retcode) { 5 }

      it "disables downloading release notes via relnotes_url" do
        expect(described_class).to receive(:disable!).and_call_original
        fetcher.release_notes(prefs)
      end
    end

    context "when release notes URL is not valid" do
      let(:relnotes_url) { "http" }

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end
    end

    context "when release notes URL is nil" do
      let(:relnotes_url) { nil }

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end
    end

    context "when release notes URL is empty" do
      let(:relnotes_url) { "" }

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end
    end

    context "when relnotes_url is blacklisted" do
      before do
        described_class.add_to_blacklist(relnotes_url)
      end

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end

      it "does not tries to download anything" do
        expect(Yast::SCR).to_not receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl/)
        fetcher.release_notes(prefs)
      end
    end

    context "when release notes downloading is disabled" do
      before do
        described_class.disable!
      end

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end

      it "does not tries to download anything" do
        expect(Yast::SCR).to_not receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /curl/)
        fetcher.release_notes(prefs)
      end
    end

    context "when a proxy is needed " do
      let(:proxy_enabled) { true }

      before do
        allow(Yast::Proxy).to receive(:http).twice.and_return("http://proxy.example.com")
        allow(Yast::Proxy).to receive(:user).and_return(proxy_user)
        allow(Yast::Proxy).to receive(:pass).and_return(proxy_pass)
        test = {
          "HTTP" => {
            "tested" => true,
            "exit"   => 0
          }
        }
        allow(Yast::Proxy).to receive(:RunTestProxy).and_return(test)
      end

      context "and no user or password are specified" do
        let(:proxy_user) { "" }
        let(:proxy_pass) { "" }

        it "uses an unauthenticated proxy" do
          expect(Yast::SCR).to receive(:Execute) do |_path, cmd|
            expect(cmd).to include("--proxy http://proxy.example.com")
            expect(cmd).to_not include("--proxy-user")
          end

          fetcher.release_notes(prefs)
        end
      end

      context "and user and password are specified" do
        let(:proxy_user) { "baggins" }
        let(:proxy_pass) { "thief" }

        it "uses an authenticated proxy" do
          expect(Yast::SCR).to receive(:Execute) do |_path, cmd|
            expect(cmd).to include("--proxy http://proxy.example.com --proxy-user 'baggins:thief'")
          end

          fetcher.release_notes(prefs)
        end
      end
    end
  end

  describe "#latest_version" do
    it "returns :latest" do
      expect(fetcher.latest_version).to eq(:latest)
    end
  end
end
