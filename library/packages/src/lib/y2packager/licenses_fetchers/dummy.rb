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
    # FIXME: Finish implementation
    class Dummy < Base
      def initialize(product_name, options = {})
        super
        @content = options[:content]
      end
      # Return the license text to be confirmed
      #
      # It will return the empty string ("") if the license does not exist or if
      # it was already confirmed.
      #
      # @param lang [String] Language
      # @return [String,nil] Product's license; nil if the product was not found.
      def license_content(_lang)
        @content
      end

      # Return available locales for product's license
      #
      # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
      def license_locales
        [License::DEFAULT_LANG]
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def license_confirmation_required?
        false
      end
    end
  end
end
