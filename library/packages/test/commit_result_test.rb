#!/usr/bin/env rspec
# typed: false

require_relative "test_helper"
require "packages/update_message"
require "packages/commit_result"

describe Packages::CommitResult do
  let(:message) do
    {
      "solvable"         => "package",
      "text"             => "Some cool message!",
      "installationPath" => "/var/adm/update-messages/package-1.0",
      "currentPath"      => "/mnt/var/adm/update-messages/package-1.0"
    }
  end

  let(:old_result) do
    [1, ["pkg1"], ["pkg2"], ["pkg3"], [message]]
  end

  describe ".from_result" do
    it "builds a new instance from Pkg.Commit/Pkg.PkgCommit return value" do
      result = Packages::CommitResult.from_result(old_result)
      expect(result.successful).to eq(1)
      expect(result.failed).to eq(["pkg1"])
      expect(result.remaining).to eq(["pkg2"])
      expect(result.srcremaining).to eq(["pkg3"])
      expect(result.update_messages)
        .to eq([Packages::UpdateMessage.new(message["solvable"], message["text"], message["installationPath"], message["currentPath"])])
    end

    context "when result is a failure" do
      let(:old_result) { [-1] }

      it "builds a new instance from Pkg.Commit/Pkg.PkgCommit return value" do
        result = Packages::CommitResult.from_result(old_result)
        expect(result.successful).to eq(-1)
        expect(result.failed).to be_empty
        expect(result.remaining).to be_empty
        expect(result.srcremaining).to be_empty
        expect(result.update_messages).to be_empty
      end
    end
  end
end
