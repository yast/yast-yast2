#!/usr/bin/env rspec

require_relative "test_helper"

require "packages/package_downloader"

describe Yast2::PackageDownloader do
  Yast.import "Pkg"

  let(:repo_id) { 1 }
  let(:package) { "package_to_download" }
  let(:path) { "dummy" }

  subject { Yast2::PackageDownloader.new(repo_id, package) }

  describe "#download" do
    it "downloads the requested package" do
      expect(Yast::Pkg).to receive(:ProvidePackage).with(repo_id, package, path).and_return(true)
      subject.download(path)
    end

    it "raises FetchError when download fails" do
      expect(Yast::Pkg).to receive(:ProvidePackage).with(repo_id, package, path).and_return(nil)
      expect { subject.download(path) }.to raise_error(Yast2::PackageDownloader::FetchError)
    end
  end
end
