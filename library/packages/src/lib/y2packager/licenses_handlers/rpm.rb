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

module Y2Packager
  module LicensesHandlers
    # This class is responsible for interacting with an rpm in order to get/set
    # the license acceptance status for a given product
    class Rpm < Base
      NO_ACCEPTANCE_FILE = "no-acceptance-needed".freeze

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def confirmation_required?
        @package ||= find_package

        return false unless @package

        !ignore_acceptance?
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

      attr_reader :package

      def ignore_acceptance?
        tmpdir = Dir.mktmpdir

        begin
          package.extract_to(tmpdir)

          Dir.glob(File.join(tmpdir, "**", NO_ACCEPTANCE_FILE), File::FNM_CASEFOLD).any?
        ensure
          FileUtils.remove_entry_secure(tmpdir)
        end
      end

      # Valid statuses for packages containing licenses
      AVAILABLE_STATUSES = [:available, :selected].freeze

      # Find the latest available/selected product package
      #
      # @return [Y2Packager::Package, nil] Package containing licenses; nil if not found
      def find_package
        return nil if package_name.nil?

        Y2Packager::Package
          .find(package_name)
          .select { |i| AVAILABLE_STATUSES.include?(i.status) }
          .sort { |a, b| Yast::Pkg.CompareVersions(a.version, b.version) }
          .last
      end

      # Find the package name
      #
      # @return [String, nil] the package name for the product; nil if not found
      def package_name
        return @package_name if @package_name

        package_properties = Yast::Pkg.ResolvableProperties(product_name, :product, "").first || {}

        @package_name = package_properties.fetch("product_package", nil)
      end
    end
  end
end
