# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "y2packager/product_license"

module Y2Packager
  # This module is used for sharing the license related methods
  # for several types of products.
  module ProductLicenseMixin
    # Return the license to confirm
    #
    # @param lang [String] Language
    # @return [ProductLicense,nil] Product's license; nil if the license was not found.
    def license
      @license ||= ProductLicense.find(name)
    end

    # Return the license text to be confirmed
    #
    # @param lang [String] Language
    # @return [String] Product's license; empty string ("") if no license was found.
    def license_content(lang)
      return "" unless license?

      license.content_for(lang)
    end

    # Determines whether the product has a license
    #
    # @param lang [String] Language
    # @return [Boolean] true if the product has a license
    def license?
      !!license
    end

    # Determine whether the license should be accepted or not
    #
    # @return [Boolean] true if the license acceptance is required
    def license_confirmation_required?
      return false unless license?

      license.confirmation_required?
    end

    # Set license confirmation for the product
    #
    # @param confirmed [Boolean] determines whether the license should be accepted or not
    def license_confirmation=(confirmed)
      return unless license

      confirmed ? license.accept! : license.reject!
    end

    # Determine whether the license is confirmed
    #
    # @return [Boolean] true if the license was confirmed (or acceptance was not needed)
    def license_confirmed?
      return false unless license

      license.accepted? || !license_confirmation_required?
    end

    # [String] Default license language.
    DEFAULT_LICENSE_LANG = "en_US".freeze

    # Return available locales for product's license
    #
    # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
    def license_locales
      license.locales
    end
  end
end
