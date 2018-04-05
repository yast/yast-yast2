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
    class Rpm < Base
      # Return the license text to be confirmed
      #
      # @param lang [String] Language
      # @return [String,nil] Product's license; nil if the product or the license were not found.
      def content(lang)
        Yast::Pkg.PrdGetLicenseToConfirm(product_name, lang)
      end

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
        locales[empty_idx] = License::DEFAULT_LANG if empty_idx
        locales
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def confirmation_required?
        Yast::Pkg.PrdNeedToAcceptLicense(product_name)
      end
    end
  end
end
