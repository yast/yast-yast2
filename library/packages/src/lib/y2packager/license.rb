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
require "digest"
require "y2packager/licenses_fetchers"

module Y2Packager
  # Represent a License which could be the same for multiple products.
  #
  # This class represents a license.
  class License
    DEFAULT_LANG = "en_US".freeze

    # @return [Boolean] whether the license has been accepted or not
    attr_reader :accepted

    # @return [Hash<String, String>] language -> content
    attr_reader :translations

    # @return [Y2Packager::LicensesFetchers::Base] License fetcher object
    attr_reader :fetcher

    alias_method :accepted?, :accepted

    class << self
      # Find a license for a given product
      #
      # @param product_name [String]    Product's name
      # @param source       [:rpm,:url] Source to get the license from. For the time being,
      #   only :rpm is really supported.
      # @return [License]
      def find(product_name, source)
        return cache[product_name] if cache[product_name]

        # This could be done in the constructor.
        fetcher = LicensesFetchers.for(source, product_name)
        new_license = License.new(fetcher)
        return unless new_license.id

        eq_license = cache.values.find { |l| l.id == new_license.id }
        license = eq_license || new_license
        cache[product_name] = license
      end

      def clear_cache
        @cache = nil
      end

      private def cache
        @cache ||= {}
      end
    end

    # Constructor
    #
    # @param options [Hash<String, String>]
    def initialize(fetcher)
      @accepted = false
      @fetcher = fetcher
      @translations = {}
    end

    # License unique identifier
    #
    # This identifier is based on the given default language translation.
    #
    # @return [String,nil] Unique identifier; nil if the license was not found.
    def id
      return @id if @id
      content = content_for(DEFAULT_LANG)
      return unless content
      @id = Digest::MD5.hexdigest(content_for(DEFAULT_LANG))
    end

    # Return the license translated content for the given language
    #
    # It will return the empty string ("") if the license does not exist
    #
    # @param [String] language
    # @return [String,nil] the license translated content or nil if not found
    def content_for(lang = DEFAULT_LANG)
      return @translations[lang] if @translations[lang]
      content = fetcher.license_content(lang)
      return add_content_for(lang, content) if content
      content_for(DEFAULT_LANG) unless lang == DEFAULT_LANG
    end

    # FIXME: Probably the locales should be obtained through the licenses
    # translations, and probably could be initialized the first time a license
    # is instantiated.
    def locales
      fetcher.license_locales
    end

    def license_confirmation_required?
      # FIXME
      true
    end

    # Add the license translated content for the given language
    #
    # @param lang [String]
    # @param content [String]
    # @return [String,nil] the license translated content or nil if not found
    def add_content_for(lang, content)
      @translations[lang] = content
    end

    # Set the license as accepted
    def accept!
      @accepted = true
    end

    # Set the license as rejected
    def reject!
      @accepted = false
    end
  end
end
