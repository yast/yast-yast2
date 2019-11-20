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
require "y2packager/resolvable"

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from a RPM package
    class Rpm < Archive
    # FIXME: there's (ATM) no way to indent the 'private' below so rubocop accepts it
    # rubocop:disable Layout/IndentationWidth

    private

      # rubocop:enable Layout/IndentationWidth

      # Check if a license archive exists
      #
      # @return [Boolean] True, if an archive exists
      def archive_exists?
        !package.nil?
      end

      # Unpack license archive
      #
      # This will unpack the archive once and keep the temporary directory.
      #
      # If the unpacking fails, the directory is still returned but the
      # directory is empty.
      #
      # The provisioning of a temporary dir is done be the parent class.
      #
      # @return [String] Unpacked archive directory
      def unpack_archive
        if !archive_dir
          archive_dir = super
          package&.extract_to(archive_dir)
        end
        archive_dir
      end

      # Find the highest version of available/selected product package
      #
      # @return [Y2Packager::Package, nil] Package containing licenses; nil if not found
      def package
        @package ||= Y2Packager::Package.last_version(package_name) if !package_name.nil?

        log.info("No license package found for #{product_name}") if @package.nil?

        @package
      end

      # Find the package name
      #
      # @return [String, nil] the package name for the product; nil if not found
      def package_name
        return @package_name if @package_name

        package_property = Y2Packager::Resolvable.find(kind: :product, name: product_name).first
        @package_name = package_properties.product_package if package_property
      end
    end
  end
end
