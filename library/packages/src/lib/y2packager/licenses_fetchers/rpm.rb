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

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from a RPM package
    class Rpm < Archive

    private

      def archive_exists?
        !package.nil?
      end

      def unpack_archive
        if !archive_dir
          archive_dir = super
          package.extract_to(archive_dir) if !package.nil?
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

        package_properties = Yast::Pkg.ResolvableProperties(product_name, :product, "")
        package_properties = package_properties.find { |props| props.key?("product_package") }
        package_properties ||= {}

        @package_name = package_properties.fetch("product_package", nil)
      end
    end
  end
end
