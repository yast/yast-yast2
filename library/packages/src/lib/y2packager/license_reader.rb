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
require "y2packager/license"
require "y2packager/license_store"
require "y2packager/licenses_fetchers/rpm"
require "y2packager/licenses_fetchers/url"

module Y2Packager
  # This class is able to read the license of a given product
  class LicenseReader
    include Yast::Logger

    attr_reader :product_name
    attr_reader :source

    # Constructor
    #
    # @param product_name [String] Product name to get licenses for
    # @param source       [Symbol] Source to use for fetching the license from
    def initialize(product_name, source = :rpm)
      @product_name = product_name
      @source = source
    end

    # Get the license for the current product name.
    #
    # @return [License, nil] License or nil if license was not found
    def license
      license = store.license_for(product_name)
      return license if license

      content = fetcher.license_content(License::DEFAULT_LANG)
      return unless content

      store.add_license_for(product_name, License.new(content: content))
    end

    # Return the license text
    #
    # It will return the empty string ("") if the license does not exist
    #
    # @param lang [String] Language
    # @return [String,nil] Product's license; nil if the product was not found.
    def license_content(lang)
      return nil unless license
      content = license.content_for(lang)
      return content if content
      content = fetcher.license_content(lang)
      return unless content
      license.add_content_for(lang, content)
    end

    # FIXME: Probably the locales should be obtained through the licenses
    # translations, and probably could be initialized the first time a license
    # is instantiated.
    def locales
      fetcher.license_locales
    end

    # Determine whether the license should be accepted or not
    #
    # @return [Boolean] true if the license acceptance is required
    def license_confirmation_required?
      fetcher.license_confirmation_required?
    end

    # Fallback language
    DEFAULT_LANG = "en".freeze

  private

    def fetcher
      fetchers = {
        rpm: LicensesFetchers::Rpm.new(product_name),
        url: LicensesFetchers::Url.new(product_name)
      }

      fetchers[source]
    end

    # Determine whether the system is registered
    #
    # @return [Boolean]
    def registered?
      require "registration/registration"
      Registration::Registration.is_registered?
    rescue LoadError
      false
    end

    def store
      LicenseStore.instance
    end
  end
end
