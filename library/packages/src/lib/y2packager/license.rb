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
    # Default language for licenses.
    DEFAULT_LANG = "en_US".freeze

    # @return [Boolean] whether the license has been accepted or not
    attr_reader :accepted

    # @return [Hash<String, String>] language -> content
    attr_reader :translations

    alias_method :accepted?, :accepted

    class << self
      # Find a license for a given product
      #
      # This method uses a cache to return the same license if it was already
      # used for another product.
      #
      # @param product_name [String]   Product's name
      # @param source       [:rpm,nil] Source to get the license from. For the time being,
      #   only :rpm is supported.
      # @param content      [String]   License content. If this argument is given, this
      #   string is used as the license's content (and `source` is ignored).
      # @return [License]
      def find(product_name, source: nil, content: nil)
        return cache[product_name] if cache[product_name]

        fetcher = source ? LicensesFetchers.for(source, product_name) : nil
        new_license = License.new(fetcher: fetcher, content: content)
        return unless new_license.id

        eq_license = cache.values.find { |l| l.id == new_license.id }
        license = eq_license || new_license
        cache[product_name] = license
      end

      # Clean licenses cache
      def clear_cache
        @cache = nil
      end

    private

      # Licenses cache
      #
      # @return [Hash<String,License>]
      def cache
        @cache ||= {}
      end
    end

    # Constructor
    #
    # This class should be able to use the proper fetcher (see Y2Packager::LicensesFetchers)
    # in order to retrieve license content (including translations). However, for compatibility
    # reasons, the constructor can receive a `content` that will be used as licence's
    # content. The reason is that, in some parts of YaST, the license content/translations
    # is retrieved in different ways. We might need to unify them.
    #
    # Bear in mind that `fetcher` will be ignored if `content` is specified.
    #
    # @param fetcher [:rpm]   Fetcher to retrieve licenses information. For the time
    #   being, only :rpm is supported.
    # @param content [String] License content. If this argument is given, this
    #   string is used as the license's content (and `source` is ignored).
    def initialize(fetcher: nil, content: nil)
      @accepted = false
      @translations = {}
      if content
        add_content_for(DEFAULT_LANG, content)
      else
        @fetcher = fetcher
      end
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
      @id = Digest::MD5.hexdigest(content)
    end

    # Return the license translated content for the given language
    #
    # @param lang [String] Contents' language
    # @return [String,nil] the license translated content or nil if not found
    def content_for(lang = DEFAULT_LANG)
      return @translations[lang] if @translations[lang]
      return nil unless fetcher
      content = fetcher.content(lang)
      return add_content_for(lang, content) if content
    end

    # Return license's available locales
    #
    # @return [String] List of available locales
    def locales
      fetcher.locales
    end

    # Add the license translated content for the given language
    #
    # @param lang    [String] Language to add the translation to
    # @param content [String] Content to add
    # @return [String] the license translated content
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

  private

    # @return [Y2Packager::LicensesFetchers::Base] License fetcher object
    attr_reader :fetcher
  end
end
