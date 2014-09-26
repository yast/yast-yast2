#! /usr/bin/rspec --format=doc

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast

# to be tested:
# def UnEscapeString(_in, transform)
# def EscapeString(_in, transform)
# def Parse(url)
# def Check(url)
# def Build(tokens)
# def FormatURL(tokens, len)
# def MakeMapFromParams(params)
# def MakeParamsFromMap(params_map)
# def HidePassword(url)
# def HidePasswordToken(tokens)

describe "Yast::URL" do
  before( :all) do
    Yast.import "URL"
  end

  describe "#UnEscapeString" do
    it "decodes escaped URI string" do
      expect(Yast::URL.UnEscapeString(
        "http%3a%2f%2fsome.nice.url%2f%3awith%3a%2f%24p#ci%26l%2fch%40rs%2f",
        Yast::URL.transform_map_passwd
      )).to eq("http://some.nice.url/:with:/$p#ci&l/ch@rs/")
    end
  end

  describe "#EscapeString" do
    it "escapes URI string" do
      expect(Yast::URL.EscapeString(
        "http://some.nice.url/:with:/$p#ci&l/ch@rs/",
        Yast::URL.transform_map_passwd
      )).to eq("http%3a%2f%2fsome.nice.url%2f%3awith%3a%2f%24p#ci%26l%2fch%40rs%2f")
    end
  end

  describe "#Parse" do
    let(:result) { URL.Parse(url) }

    context "parse url with hostname" do
      let(:expected_data) {
        {
          "scheme"  => "http",
          "host"    => "www.suse.cz",
          "port"    => "80",
          "path"    => "/path/index.html",
          "user"    => "name",
          "pass"    => "pass",
          "query"   => "question",
          "fragment"=> "part"
        }
      }

      let(:url) { "http://name:pass@www.suse.cz:80/path/index.html?question#part" }

      it "parses http url with a hostname" do
        expect(result).to eq expected_data
      end
    end

    context "parse url with IPv4 address" do
      let(:expected_data) {
        {
          "scheme"  => "http",
          "host"    => "192.168.0.22",
          "port"    => "80",
          "path"    => "/path/index.html",
          "user"    => "name",
          "pass"    => "pass",
          "query"   => "question",
          "fragment"=> "part"
        }
      }

      let(:url) { "http://name:pass@192.168.0.22:80/path/index.html?question#part" }

      it "parses an numeric IPv4 address" do
        expect(result).to eq expected_data
      end
    end

    context "parse url with IPv6 address" do
      let(:expected_data) {
        {
          "scheme"  => "http",
          "host"    => "1080:0:0:0:8:800:200C:417A",
          "port"    => "80",
          "path"    => "/path/index.html",
          "user"    => "name",
          "pass"    => "pass",
          "query"   => "question",
          "fragment"=> "part"
        }
      }

      let(:url) { "http://name:pass@[1080:0:0:0:8:800:200C:417A]:80/path/index.html?question#part" }

      it "parses a n IPv6 address" do
        expect(result).to eq expected_data
      end
    end

    context "parse ftp url" do
      let(:expected_data) {
        {
          "scheme"=>"ftp",
          "path"=>"pub/standards/RFC/rfc959.txt",
          "query"=>"",
          "fragment"=>"",
          "user"=>"name",
          "pass"=>"pass",
          "port"=>"2020",
          "host"=>"ftp.funet.fi"
        }
      }

      let(:url) { "ftp://name:pass@ftp.funet.fi:2020/pub/standards/RFC/rfc959.txt" }

      it "parses a ftp address" do
        expect(result).to eq expected_data
      end
    end

    context "parse smb url" do
      let(:expected_data) {
        {
          "scheme"=>"smb",
          "path"=>"/share/path/on/the/share",
          "query"=>"workgroup=mygroup",
          "fragment"=>"",
          "user"=>"username",
          "pass"=>"passwd",
          "port"=>"",
          "host"=>"servername",
          "domain"=>"mygroup"}
      }

      let(:url) { "smb://username:passwd@servername/share/path/on/the/share?workgroup=mygroup" }

      it "recognizes schmeme 'smb'" do
        expect(result).to eq expected_data
      end
    end

    context "parse samba url" do
      let(:expected_data) {
        {
          "scheme"=>"samba",
          "path"=>"/share/path/on/the/share",
          "query"=>"workgroup=mygroup",
          "fragment"=>"",
          "user"=>"username",
          "pass"=>"passwd",
          "port"=>"",
          "host"=>"servername",
          "domain"=>"mygroup"}
      }

      let(:url) { "samba://username:passwd@servername/share/path/on/the/share?workgroup=mygroup" }

      it "recognizes scheme 'samba'" do
        expect(result).to eq expected_data
      end
    end

  end
end
