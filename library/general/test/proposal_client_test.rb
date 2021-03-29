#! /usr/bin/env rspec
# typed: false

require_relative "test_helper"

require "installation/proposal_client"

class TestProposal < ::Installation::ProposalClient
  def make_proposal(args)
    args.empty? ? "make_proposal" : args
  end

  def ask_user(args)
    args.empty? ? "ask_user" : args
  end

  def description
    "description"
  end

  def write
    "write"
  end
end

describe ::Installation::ProposalClient do
  subject { ::TestProposal }
  describe ".run" do
    it "raise ArgumentError exception if unknown first argument is passed" do
      allow(Yast::WFM).to receive(:Args).and_return(["Unknown", {}])
      expect { ::Installation::ProposalClient.run }.to raise_error(ArgumentError)
    end

    context "first client argument is MakeProposal" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["MakeProposal", {}])
      end

      it "dispatch call to abstract method make_proposal" do
        expect(subject.run).to eq "make_proposal"
      end

      it "passes argument hash to abstract method" do
        test_params = { a: :b, c: :d }
        allow(Yast::WFM).to receive(:Args).and_return(["MakeProposal", test_params])

        expect(subject.run).to eq test_params
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect { ::Installation::ProposalClient.run }.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is AskUser" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["AskUser", {}])
      end

      it "dispatch call to abstract method ask_user" do
        expect(subject.run).to eq "ask_user"
      end

      it "passes argument hash to abstract method" do
        test_params = { a: :b, c: :d }
        allow(Yast::WFM).to receive(:Args).and_return(["AskUser", test_params])

        expect(subject.run).to eq test_params
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect { ::Installation::ProposalClient.run }.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Description" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Description", {}])
      end

      it "dispatch call to abstract method description" do
        expect(subject.run).to eq "description"
      end

      it "raise NotImplementedError exception if abstract method not defined" do
        expect { ::Installation::ProposalClient.run }.to raise_error(NotImplementedError)
      end
    end

    context "first client argument is Write" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return(["Write", {}])
      end

      it "dispatch call to abstract method write" do
        expect(subject.run).to eq "write"
      end

      it "succeeds even if write  method is not defined" do
        expect { ::Installation::ProposalClient.run }.to_not raise_error
      end
    end
  end
end
