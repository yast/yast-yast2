# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "yast2/execute"
require "packages/package_downloader"
require "packages/package_extractor"
require "tempfile"

Yast.import "Pkg"

module Y2Packager
  # This class represents a libzypp package and it offers an API to common operations.
  #
  # The idea is extending this class with new methods when needed.
  class Package
    include Yast::Logger

    # @return [String] Package name
    attr_reader :name
    # @return [Integer] Id of the repository where the package lives
    attr_reader :repo_id
    # @return [String] Package version
    attr_reader :version

    class << self
      # Find packages by name
      #
      # @param name [String] Package name
      # @return [Array<Package>,nil] Packages named like `name`. It returns `nil`
      #   if some problem occurs interacting with libzypp.
      def find(name)
        props = Yast::Pkg.ResolvableProperties(name, :package, "")
        return nil if props.nil?
        props.map { |i| new(i["name"], i["source"], i["version"]) }
      end
    end

    # Constructor
    #
    # @param name    [String]  Package name
    # @param repo_id [Integer] Repository ID
    # @param version [String]  Package version
    def initialize(name, repo_id, version)
      @name = name
      @repo_id = repo_id
      @version = version
    end

    # Return package status
    #
    # Ask libzypp about package status.
    #
    # @return [Symbol] Package status (:installed, :available, etc.)
    # @see Yast::Pkg.PkgProperties
    def status
      Yast::Pkg.PkgProperties(name)["status"]
    end

    # Download a package to the given path
    #
    # @param path [String,Pathname] Path to download the package to
    # @see Packages::PackageDownloader
    def download_to(path)
      downloader = Packages::PackageDownloader.new(repo_id, name)
      downloader.download(path.to_s)
    end

    # Download and extract the package to the given directory
    #
    # @param directory [String,Pathname] Path to extract the package to
    # @see Packages::PackageExtractor
    def extract_to(directory)
      tmpfile = Tempfile.new("downloaded-package-#{name}-")
      download_to(tmpfile.path)
      extractor = Packages::PackageExtractor.new(tmpfile.path)
      extractor.extract(directory.to_s)
    ensure
      tmpfile.close
      tmpfile.unlink
    end
  end
end
