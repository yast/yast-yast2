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
require "y2packager/licenses_fetchers/base"

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
      # @param product_name [String] to get licenses for
      def initialize(product_name, _options = {})
        @product_name = product_name
      end

      # Check if is a valid fecher based on content for default language
      #
      # @return [Booelan] true if there is content for the default language; false otherwise.
      def found?
        !default_content.empty?
      end

      def content(lang)
        return @default_content if default_lang?(lang) && @default_content
      end

    private

      # Return (and caches) the content found for the default language
      #
      # @return [String] the license content for the default language; empty if nothing was found.
      def default_content
        @default_content ||= content(DEFAULT_LANG).to_s
      end

      def default_lang?(lang)
        lang == DEFAULT_LANG
      end
    end
  end
end
