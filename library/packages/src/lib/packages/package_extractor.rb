# typed: false
# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "shellwords"

require "yast"
require "yast2/execute"

module Packages
  # Extracts the RPM package contents to a directory.
  #
  # @example Extracting a package into a temporary directory
  #  extractor = PackageExtractor("./my_package-0.1-0.noarch.rpm")
  #  Dir.mktmpdir do |tmpdir|
  #    extractor.extract(tmpdir)
  #    # do something with the content in tmpdir...
  #  end
  class PackageExtractor
    include Yast::Logger

    # Path to the package to extract.
    # @return [String] package path
    attr_reader :package_path

    # The package could not be extracted
    class ExtractionFailed < StandardError; end

    # Constructor
    #
    # @param package_path [String] the path to the package to extract
    def initialize(package_path)
      @package_path = package_path
    end

    # Command to extract an RPM, the contents is extracted into the current
    # working directory.
    EXTRACT_CMD = "rpm2cpio %<source>s | cpio --quiet --sparse -dimu --no-absolute-filenames".freeze

    # Extracts the RPM contents to the given directory.
    #
    # It is responsibility of the caller to remove the extracted content
    # when it is not needed anymore.
    #
    # @param dir [String] Directory where the RPM contents will be extracted to
    #
    # @raise ExtractionFailed
    def extract(dir)
      Dir.chdir(dir) do
        cmd = format(EXTRACT_CMD, source: Shellwords.escape(package_path))
        log.info("Extracting package #{package_path} to #{dir}...")

        # we need a shell to process the pipe,
        # the "allowed_exitstatus" option forces Cheetah to return the exit code
        ret = Yast::Execute.locally("sh", "-c", cmd, allowed_exitstatus: 0..255)
        log.info("Extraction result: #{ret}")

        raise ExtractionFailed unless ret.zero?
      end
    end
  end
end
