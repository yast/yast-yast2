#!/usr/bin/env rspec

require "tempfile"
require_relative "test_helper"
require "packages/package_extractor"

describe Packages::PackageExtractor do
  # a testing RPM package
  let(:dummy_package_path) { File.expand_path("../../data/rpm/dummy_package-0.1-0.noarch.rpm", __FILE__) }
  # the testing file in the package
  let(:dummy_file) { "usr/share/doc/packages/dummy_package/test" }
  # the contents of the testing file
  let(:dummy_file_contents) { "just a testing dummy package\n" }

  describe "#extract" do
    it "extracts the package" do
      Dir.mktmpdir do |tmpdir|
        extractor = Packages::PackageExtractor.new(dummy_package_path)
        extractor.extract(tmpdir)

        # check the extracted content
        extracted = File.join(tmpdir, dummy_file)
        expect(File.file?(extracted)).to be(true)
        expect(File.read(extracted)).to eq(dummy_file_contents)
      end
    end

    it "raises ExtractionFailed when the extraction fails" do
      Dir.mktmpdir do |tmpdir|
        extractor = Packages::PackageExtractor.new("non-existing-package")
        expect { extractor.extract(tmpdir) }.to raise_error(Packages::PackageExtractor::ExtractionFailed)
      end
    end
  end
end
