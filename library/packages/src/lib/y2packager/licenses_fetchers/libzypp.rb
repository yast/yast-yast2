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

require "y2packager/licenses_fetchers/base"

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from libzypp.
    class Libzypp < Base
      # Return available locales for product's license
      #
      # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
      def locales
        locales = Yast::Pkg.PrdLicenseLocales(product_name)

        if locales.nil?
          log.error "Error getting the list of available license translations for '#{product_name}'"
          return []
        end

        empty_idx = locales.index("")
        locales[empty_idx] = DEFAULT_LANG if empty_idx
        locales
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if license acceptance is required
      def confirmation_required?
        Yast::Pkg.PrdNeedToAcceptLicense(product_name)
      end

    private

      def license_content_for(lang)
        Yast::Pkg.PrdGetLicenseToConfirm(product_name, lang)
      end
    end
  end
end
