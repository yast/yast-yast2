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

require "yast"

require "tempfile"
require "shellwords"

require "yast2/execute"

Yast.import "Pkg"

module Packages
  # Downloads a package from a known package manager (libzypp) repository.
  #
  # @note For downloading files outside of a libzypp repository use the
  # FileFromUrl::get_file_from_url method:
  # https://github.com/yast/yast-installation/blob/fba82c3c9abfc44e3d31c8658bf96079d74e0298/src/lib/transfer/file_from_url.rb#L89
  #
  # @example Downloading a package
  #   begin
  #     downloader = PackageDownloader.new(3, "yast2")
  #     tmp = Tempfile.new("downloaded-package-")
  #     downloader.download(tmp.path)
  #     # do something with the package...
  #   ensure
  #     tmp.close
  #     tmp.unlink
  #   end
  #
  class PackageDownloader
    include Yast::Logger
    include Yast::I18n

    # @return [Integer] Repository ID
    attr_reader :repo_id
    # @return [String] Name of the package
    attr_reader :package_name

    # Error while downloading the package.
    class FetchError < StandardError; end

    # Constructor
    #
    # @param [Integer] repo_id Repository ID
    # @param [String] package_name Name of the package to download
    def initialize(repo_id, package_name)
      textdomain "base"

      @repo_id = repo_id
      @package_name = package_name
    end

    # Download the package locally to the given path.
    #
    # It is responsibility of the caller to remove the downloaded package
    # when it is not needed anymore.
    #
    # @param path [#to_s] path where the downloaded package will be stored
    #
    # @raise PackageNotFound
    def download(path)
      log.info("Downloading package #{package_name} from repo #{repo_id} to #{path}")
      return if Yast::Pkg.ProvidePackage(repo_id, package_name, path.to_s)

      log.error("Package #{package_name} could not be retrieved.")
      raise FetchError
    end
  end
end
