#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/package"
require "fileutils"

describe Y2Packager::Package do
  subject(:package) { Y2Packager::Package.new("release-notes-dummy", 1, "15.0") }

  let(:downloader) { instance_double(Packages::PackageDownloader, download: nil) }

  describe ".find" do
    let(:name) { "yast2" }
    let(:package) { instance_double(Y2Packager::Package) }

    it "returns packages with a given name" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with(name, :package, "")
        .and_return([{ "name" => "yast2", "source" => 1, "version" => "12.3" }])
      expect(Y2Packager::Package).to receive(:new).with(name, 1, "12.3")
        .and_return(package)
      expect(described_class.find(name)).to eq([package])
    end
  end

  describe "#download_to" do
    it "downloads the package" do
      expect(Packages::PackageDownloader).to receive(:new)
        .with(package.repo_id, package.name).and_return(downloader)
      expect(downloader).to receive(:download).with(FIXTURES_PATH.to_s)
      package.download_to(FIXTURES_PATH)
    end

    context "when package download fails" do
      before do
        allow(downloader).to receive(:download)
          .and_raise(Packages::PackageDownloader::FetchError)
      end

      it "raises the error" do
        expect { package.download_to(FIXTURES_PATH) }
          .to raise_error(Packages::PackageDownloader::FetchError)
      end
    end
  end

  describe "#extract_to" do
    let(:extractor) { instance_double(Packages::PackageExtractor, extract: nil) }
    let(:tempfile) do
      instance_double(Tempfile, close: nil, unlink: nil, path: "/tmp/some-package")
    end

    before do
      allow(Packages::PackageExtractor).to receive(:new).and_return(extractor)
      allow(Tempfile).to receive(:new).and_return(tempfile)
      allow(package).to receive(:download_to)
    end

    it "extracts the content to the given path" do
      expect(Packages::PackageExtractor).to receive(:new).with(tempfile.path)
        .and_return(extractor)
      expect(extractor).to receive(:extract).with("/path")
      package.extract_to("/path")
    end

    context "when the package could not be extracted" do
      before do
        allow(extractor).to receive(:extract)
          .and_raise(Packages::PackageExtractor::ExtractionFailed)
      end

      it "raises the error" do
        expect { package.extract_to("/path") }
          .to raise_error(Packages::PackageExtractor::ExtractionFailed)
      end
    end
  end

  describe "#status" do
    it "returns package status" do
      expect(Yast::Pkg).to receive(:PkgProperties)
        .with(package.name).and_return("status" => :available)
      expect(package.status).to eq(:available)
    end
  end
end
