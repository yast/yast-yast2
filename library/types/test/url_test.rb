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
  end

  describe ".Build" do
    it "returns the URL for the given tokens" do
      expect(subject.Build(tokens)).to eq(url)
    end

    context "given a cd/dvd URL" do
      let(:tokens) do
        {
          "scheme" => "cd",
          "query"  => "device=/dev/sr0"
        }
      end

      it "returns a URL containing which a single slash to separate the schema from the rest" do
        expect(subject.Build(tokens)).to eq("cd:/?device=/dev/sr0")
      end
    end
  end
end
