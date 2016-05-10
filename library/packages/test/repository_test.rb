#!/usr/bin/env rspec

require_relative "test_helper"
require "packages/repository"
require "uri"

describe Packages::Repository do
  Yast.import "Pkg"

  let(:repo_id) { 1 }
  let(:enabled) { true }
  let(:autorefresh) { true }
  let(:repo_url) { URI("http://download.opensuse.org/update/leap/42.1/oss") }

  subject(:repo) do
    Packages::Repository.new(repo_id: repo_id, name: "repo-oss", enabled: enabled,
      autorefresh: autorefresh, url: repo_url)
  end

  let(:disabled) do
    Packages::Repository.new(repo_id: repo_id + 1, name: "disabled-repo", enabled: false,
      autorefresh: false, url: repo_url)
  end

  describe ".all" do
    before do
      expect(Yast::Pkg).to receive(:SourceGetCurrent).with(false).and_return(repo_ids)
    end

    context "when no repository exist" do
      let(:repo_ids) { [] }

      it "returns a empty array" do
        expect(described_class.all).to eq([])
      end
    end

    context "when a repository exist" do
      let(:repo_ids) { [repo_id] }
      let(:repo) { double("repo") }

      it "returns an array containing existing repositories" do
        expect(described_class).to receive(:find).with(repo_id).and_return(repo)
        expect(described_class.all).to eq([repo])
      end
    end
  end

  describe ".enabled" do
    before do
      allow(Packages::Repository).to receive(:all).and_return([repo, disabled])
    end

    it "returns enabled repositories" do
      expect(Packages::Repository.enabled).to eq([repo])
    end
  end

  describe ".disabled" do
    before do
      allow(Packages::Repository).to receive(:all).and_return([repo, disabled])
    end

    it "returns disabled repositories" do
      expect(Packages::Repository.disabled).to eq([disabled])
    end
  end

  describe ".find" do
    before do
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(repo_id).and_return(repo_data)
    end

    context "when a valid repo_id is given" do
      let(:repo_data) do
        { "enabled" => true, "autorefresh" => true, "url" => repo_url,
          "name" => "Repo #1" }
      end

      it "returns a repository with the given repo_id" do
        repo = described_class.find(repo_id)
        expect(repo.repo_id).to eq(repo_id)
        expect(repo.enabled?).to eq(repo_data["enabled"])
        expect(repo.url).to eq(URI(repo_data["url"]))
      end
    end

    context "when an invalid repo_id is given" do
      let(:repo_data) { nil }

      it "raises a RepositoryNotFound error" do
        expect { described_class.find(repo_id) }.to raise_error(Packages::Repository::NotFound)
      end
    end
  end

  describe "#scheme" do
    context "when URL contains a scheme" do
      let(:repo_url) { URI("cd://dev/sr1") }

      it "returns the repository scheme" do
        expect(subject.scheme).to eq(:cd)
      end
    end

    context "when URL does not contain a scheme" do
      let(:repo_url) { URI("/home/user/myrepo") }

      it "returns nil" do
        expect(subject.scheme).to be_nil
      end
    end
  end

  describe "#enabled?" do
    context "when the repo is enabled" do
      let(:enabled) { true }

      it "returns true" do
        expect(subject).to be_enabled
      end
    end

    context "when the repo is not enabled" do
      let(:enabled) { false }

      it "returns false" do
        expect(subject).to_not be_enabled
      end
    end
  end

  describe "#autorefresh?" do
    context "when the repo is autorefresh" do
      let(:autorefresh) { true }

      it "returns true" do
        expect(subject).to be_autorefresh
      end
    end

    context "when the repo is not autorefresh" do
      let(:autorefresh) { false }

      it "returns false" do
        expect(subject).to_not be_autorefresh
      end
    end
  end

  describe "#products" do
    let(:products_data) { [product1] }
    let(:product1) do
      { "arch" => "x86_64", "name" => "openSUSE", "category" => "addon",
        "status" => :available, "source" => repo_id, "vendor" => "openSUSE" }
    end

    it "returns products available in the repository" do
      allow(Yast::Pkg).to receive(:ResolvableProperties).with("", :product, "").
        and_return(products_data)
      product = subject.products.first
      expect(product.name).to eq("openSUSE")
    end
  end

  describe "#enable!" do
    it "enables the repository" do
      expect(Yast::Pkg).to receive(:SourceSetEnabled).with(disabled.repo_id, true).and_return(true)
      expect { disabled.enable! }.to change { disabled.enabled? }.from(false).to(true)
    end
  end

  describe "#disable!" do
    it "disables the repository" do
      expect(Yast::Pkg).to receive(:SourceSetEnabled).with(repo.repo_id, false).and_return(true)
      expect { repo.disable! }.to change { repo.enabled? }.from(true).to(false)
    end
  end
end
