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

require "y2packager/licenses_handlers/base"

Yast.import "Pkg"
Yast.import "InstURL"

module Y2Packager
  module LicensesHandlers
    # This class is responsible for interacting with an rpm in order to get/set
    # the license acceptance status for a given product
    class Tarball < Base
      NO_ACCEPTANCE_FILE = "no-acceptance-needed".freeze

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def confirmation_required?
        tmpdir = Dir.mktmpdir
        extract_archive(tmpdir)

        Dir.glob(File.join(tmpdir, "**", NO_ACCEPTANCE_FILE), File::FNM_CASEFOLD).empty?
      ensure
        FileUtils.remove_entry_secure(tmpdir)
      end

      # Set the license confirmation for the product
      #
      # @param confirmed [Boolean] true if it should be accepted; false otherwise
      def confirmation=(confirmed)
        if confirmed
          log.info("License was accepted")
        else
          log.info("License was not accepted")
        end
      end

    private

      # download the tarball from the installation medium and extract it into the directory
      def extract_archive(dir)
        url = Yast::InstURL.installInf2Url("")
        expanded_url = Yast::Pkg.ExpandedUrl(url)

        src = Yast::Pkg.RepositoryAdd("base_urls" => [expanded_url])
        tarball = Yast::Pkg.SourceProvideFile(src, 1, archive_name)

        system("tar -C #{dir.shellescape} -x -z -f #{tarball.shellescape}")
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
