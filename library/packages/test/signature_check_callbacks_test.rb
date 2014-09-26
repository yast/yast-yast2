#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

module Yast

  import "SignatureCheckCallbacks"
  import "Pkg"
  import "SignatureCheckDialogs"

  describe SignatureCheckCallbacks do
    describe "#import_gpg_key_or_disable" do

      # Values of repo_id and key are irrelevant for this test
      let(:repo_id) { 1 }
      let(:key) { {} }

      before(:each) do
        allow(SignatureCheckDialogs).to receive(:CheckSignaturesInYaST).and_return true
      end

      it "enables repositories with accepted key" do
        allow(SignatureCheckDialogs).to receive(:ImportGPGKeyIntoTrustedDialog).and_return true
        expect(Pkg).to receive(:SourceSetEnabled).with(repo_id, true)

        SignatureCheckCallbacks.import_gpg_key_or_disable(key, repo_id)
      end

      it "disables repositories with rejected key" do
        allow(SignatureCheckDialogs).to receive(:ImportGPGKeyIntoTrustedDialog).and_return false
        expect(Pkg).to receive(:SourceSetEnabled).with(repo_id, false)

        SignatureCheckCallbacks.import_gpg_key_or_disable(key, repo_id)
      end
    end
  end
end
