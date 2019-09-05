# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "y2packager/licenses_fetchers/archive"

require "shellwords"

Yast.import "InstURL"

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from a tarball archive (.tar.gz)
    class Tarball < Archive

    private

      attr_reader :archive_file_name

      def archive_exists?
        unpack_archive
        !@archive_file_name.nil?
      end

      # download the tarball from the installation medium and extract it into the directory
      def unpack_archive
        return archive_dir if archive_dir

        archive_dir = super

        url = Yast::InstURL.installInf2Url("")
        expanded_url = Yast::Pkg.ExpandedUrl(url)

        src = Yast::Pkg.RepositoryAdd("base_urls" => [expanded_url])
        @archive_file_name = Yast::Pkg.SourceProvideFile(src, 1, archive_name)

        system("tar -C #{archive_dir.shellescape} -x -f #{@archive_file_name.shellescape}") if @archive_file_name

        archive_dir
      ensure
        # remove the temporary repository
        Yast::Pkg.SourceDelete(src) if src
      end

      def archive_name
        # "license-SLES.tar.gz"
        "license-#{product_name}.tar.gz"
      end
    end
  end
end
