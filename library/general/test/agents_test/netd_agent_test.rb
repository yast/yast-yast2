require_relative "../test_helper"
require 'yast'

module Yast
  describe ".etc.xinetd_conf.services" do

    before :each do
      root = File.join(File.dirname(__FILE__), "test_root")
      set_root_path(root)
    end

    after :each do
      reset_root_path
    end

    describe ".Read" do
      let(:content) {SCR.Read(Path.new(".etc.xinetd_conf.services"))}

      it "reads content of /etc/xinetd.d and returns array" do
        expect(content).to be_a(Array)
      end

      it "returns one entry per file" do
        expect(content.size).to eq(2)
      end

      it "returns proper service names" do
        services = content.map {|i| i["service"]}.sort
        expect(services).to eq(%w(echo services))
      end

      it "only skips parsing of options specific to each service" do
        expected = [
          "\ttype\t\t= INTERNAL\n\tid\t\t= echo-stream\n\tFLAGS\t\t= IPv6 IPv4\n",
          "\ttype\t\t= INTERNAL UNLISTED\n\tport\t\t= 9098\n\tonly_from\t= 127.0.0.1\n\tFLAGS\t\t= IPv6 IPv4\n"
        ]
        unparsed = content.map {|i| i["unparsed"]}.sort
        expect(unparsed).to eq(expected)
      end
    end
  end
end
