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

require "yast"

Yast.import "Pkg"

module Y2Packager
  module LicensesFetchers
    # Base class for licenses fetchers
    class Base
      include Yast::Logger

      DEFAULT_LANG = "en_US".freeze

      # @return [String] Product name to get licenses for
      attr_reader :product_name

      # Constructor
      #
      # @param product_name [String] Product for which to get licenses
      def initialize(product_name, _options = {})
        @product_name = product_name
      end

      # Check if this is a valid fecher based on the existence of license content for default language
      #
      # @return [Booelan] true if there is license content for the default language; false otherwise
      def found?
        !default_content.empty?
      end

      # Return the license content
      #
      # @param lang [String] Language
      #
      # @return [String, nil] Product's license; nil if no license was found
      def content(lang)
        # FIXME: not #default_content at some place?
        if default_lang?(lang) && @default_content
          return (@default_content&.empty?) ? nil : @default_content
        end

        license_content_for(lang)
      end

      # Return available language codes for the license of the product
      #
      # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
      def locales
        []
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def confirmation_required?
        true
      end

    private

      # Return (and cache) the license content for the default language
      #
      # @return [String] license content for the default language; empty if nothing was found
      def default_content
        @default_content ||= content(DEFAULT_LANG).to_s
      end

      def default_lang?(lang)
        lang == DEFAULT_LANG
      end

      # Return the license content for a specific language
      #
      # When a license for language "xx_XX" is not found, fallback to "xx".
      #
      # @param lang [String] Language
      #
      # @return [Array<String, String>, nil] Array containing license content and language code
      def license_content_for(_lang)
        nil
      end
    end
  end
end
