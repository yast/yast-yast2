#! /usr/bin/env rspec

require_relative "test_helper"

require "installation/auto_client"

class TestAuto < ::Installation::AutoClient
  def import(args)
    args.empty? ? "import" : args
  end

  ["export", "summary", "reset", "change", "write", "packages", "read", "modified?", "modified"].each do |m|
    define_method(m.to_sym) { m }
  end
end

describe ::Installation::AutoClient do
  subject { ::TestAuto }
  describe ".run" do
    it "raise ArgumentError exception if unknown first argument is passed" do
      allow(Yast::WFM).to receive(:Args).and_return(["Unknown", {}])
      expect{::Installation::AutoClient.run}.to raise_error(ArgumentError)
    end

    context "first client argument is Import" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Import", {}])
      end

      it "dispatch call to abstract method import" do
        expect(subject.run).to eq "import"
      end

      it "passes argument hash to abstract method" do
        test_params = { :a => :b, :c => :d }
        allow(Yast::WFM).to receive(:Args).and_return(["Import", test_params])

        expect(subject.run).to eq test_params
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Export" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Export", {}])
      end

      it "dispatch call to abstract method export" do
        expect(subject.run).to eq "export"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Summary" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Summary", {}])
      end

      it "dispatch call to abstract method summary" do
        expect(subject.run).to eq "summary"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Reset" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Reset", {}])
      end

      it "dispatch call to abstract method reset" do
        expect(subject.run).to eq "reset"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Change" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Change", {}])
      end

      it "dispatch call to abstract method change" do
        expect(subject.run).to eq "change"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Write" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Write", {}])
      end

      it "dispatch call to abstract method write" do
        expect(subject.run).to eq "write"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Read" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Read", {}])
      end

      it "dispatch call to abstract method read" do
        expect(subject.run).to eq "read"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is GetModified" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["GetModified", {}])
      end

      it "dispatch call to abstract method modified?" do
        expect(subject.run).to eq "modified?"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is SetModified" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["SetModified", {}])
      end

      it "dispatch call to abstract method modified" do
        expect(subject.run).to eq "modified"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect{::Installation::AutoClient.run}.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Packages" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Packages", {}])
      end

      it "dispatch call to abstract method packages" do
        expect(subject.run).to eq "packages"
      end

      it "just log if optional abstract method not defined" do
        expect{::Installation::AutoClient.run}.to_not raise_error
      end

      it "returns empty array if optional abstract method not defined" do
        expect(::Installation::AutoClient.run).to eq []
      end
    end
  end
end
