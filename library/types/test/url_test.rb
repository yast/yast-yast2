#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "URL"

describe Yast::URL do
  subject { Yast::URL }

  let(:url) { "https://myuser:mypassword@suse.de:1234/some-path?preview=true#contents" }
  let(:tokens) do
    {
      "scheme"   => "https",
      "host"     => "suse.de",
      "path"     => "/some-path",
      "fragment" => "contents",
      "user"     => "myuser",
      "pass"     => "mypassword",
      "port"     => "1234",
      "query"    => "preview=true"
    }
  end

  describe ".Parse" do
    it "returns a hash containing the token extracted from the URL" do
      expect(subject.Parse(url)).to eq(tokens)
    end

    context "given a CD/DVD with a file" do
      let(:url) { "cd:/some/file" }
      let(:tokens) do
        {
          "scheme"   => "cd",
          "host"     => "",
          "path"     => "/some/file",
          "fragment" => "",
          "user"     => "",
          "pass"     => "",
          "port"     => "",
          "query"    => ""
        }
      end

      it "returns a hash containing 'scheme' and 'path'" do
        expect(subject.Parse(url)).to eq(tokens)
      end
    end

    context "given a CD/DVD with a device" do
      let(:url) { "cd:/?device=/dev/sr0" }
      let(:tokens) do
        {
          "scheme"   => "cd",
          "host"     => "",
          "path"     => "/",
          "fragment" => "",
          "user"     => "",
          "pass"     => "",
          "port"     => "",
          "query"    => "device=/dev/sr0"
        }
      end

      it "returns a hash containing 'scheme', 'path' and 'query'" do
        expect(subject.Parse(url)).to eq(tokens)
      end
    end

    context "given a CD/DVD with a device and a path" do
      let(:url) { "cd:/some/file?device=/dev/sr0" }
      let(:tokens) do
        {
          "scheme"   => "cd",
          "host"     => "",
          "path"     => "/some/file",
          "fragment" => "",
          "user"     => "",
          "pass"     => "",
          "port"     => "",
          "query"    => "device=/dev/sr0"
        }
      end

      it "returns a hash containing 'scheme', 'path' and 'query'" do
        expect(subject.Parse(url)).to eq(tokens)
      end
    end
  end

  describe ".Build" do
    it "returns the URL for the given tokens" do
      expect(subject.Build(tokens)).to eq(url)
    end

    context "given CD/DVD tokens including a device" do
      context "with a device" do
        let(:tokens) do
          {
            "scheme" => "cd",
            "query"  => "device=/dev/sr0",
            "path"   => "/"
          }
        end

        it "returns a URL of the form 'cd:///?<device>'" do
          expect(subject.Build(tokens)).to eq("cd:///?device=/dev/sr0")
        end
      end

      context "with a directory" do
        let(:tokens) do
          {
            "scheme" => "cd",
            "path"   => "/dir"
          }
        end

        it "returns a URL of the form 'cd:///<dir>'" do
          expect(subject.Build(tokens)).to eq("cd:///dir")
        end
      end
    end
  end

  describe "URLs rebuilding" do
    # This intention of these tests is to check if URLs are rebuilt correctly.

    URLS = {
      "dvd:/dir"                        => "dvd:///dir",
      "dvd://dir"                       => "dvd:///dir",
      "dvd:///dir"                      => "dvd:///dir",
      "cd:/?device=/dev/sr0"            => "cd:///?device=/dev/sr0",
      "cd:/some/file?device=/dev/sr0"   => "cd:///some/file?device=/dev/sr0",
      "cd:///some/file?device=/dev/sr0" => "cd:///some/file?device=/dev/sr0",
      "http://u:p@suse.de/a#b"          => "http://u:p@suse.de/a#b",
      "ftp://u:p@suse.de/a#b"           => "ftp://u:p@suse.de/a#b",
      "slp:/"                           => "slp://"
    }.freeze

    URLS.each do |url, rebuilt|
      it "returns '#{rebuilt}' for '#{url}'" do
        expect(subject.Build(subject.Parse(url))).to eq(rebuilt)
      end
    end
  end
end
