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
require "y2packager/licenses_handlers"

module Y2Packager
  # Represent a License which could be the same for multiple products.
  #
  # This class represents a license.
  class License
    include Yast::Logger

    # Default language for licenses.
    DEFAULT_LANG = "en_US".freeze

    # @return [Boolean] whether the license has been accepted or not
    attr_reader :accepted

    # @return [Hash<String, String>] language -> content
    attr_reader :translations

    # @return [Yast::LicensesFetchers::Base]
    attr_reader :fetcher

    # @return [Yast::LicensesHandlers::Base]
    attr_reader :handler

    alias_method :accepted?, :accepted

    class << self
      # Find a license for a given product
      #
      # This method uses a cache to return the same license if it was already
      # used for another product.
      #
      # @param product_name [String] Product's name
      # @param content      [String] License content. If this argument is given, this
      #   string is used as the license's content (and `product_name` is ignored).
      #
      # @return [License, nil]
      def find(product_name, content: nil)
        log.info "Searching for a license for product #{product_name}"
        return cache[product_name] if cache[product_name]

        fetcher = LicensesFetchers.for(product_name)
        handler = LicensesHandlers.for(fetcher, product_name) if fetcher

        license = License.new(product_name: product_name, fetcher: fetcher,
                              handler: handler, content: content)
        return unless license.id

        cached_license = cache.values.find { |l| l.id == license.id }
        if cached_license
          log.info "Found cached license: #{cached_license.id}"
        else
          log.info "Caching license: #{license.id}"
        end
        cache[product_name] = cached_license || license
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
    # @param product_name [String] Product name to retrieve license information
    # @param content      [String] License content. When given, this string is used as the license's
    #   content, ignoring the `product_name`
    # @param fetcher      [LicensesFetchers::Base] The license's fetcher
    # @param handler      [LicensesHandlers::Base] The license's handler
    def initialize(product_name: nil, content: nil, fetcher: nil, handler: nil)
      @accepted = false
      @translations = {}
      @product_name = product_name
      @fetcher = fetcher
      @handler = handler

      add_content_for(DEFAULT_LANG, content) if content
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

      @id = Digest::SHA2.hexdigest(content)
    end

    # Return the license translated content for the given language
    #
    # @param lang [String] Contents' language
    #
    # @return [String, nil] the license translated content or nil if not found
    def content_for(lang = DEFAULT_LANG)
      return @translations[lang] if @translations[lang]
      return unless fetcher

      content = fetcher.content(lang)
      add_content_for(lang, content)
    end

    # Return license's available locales
    #
    # @return [Array<String>] List of available language codes ("de_DE", "en_US", etc.)
    def locales
      return [DEFAULT_LANG] unless fetcher

      fetcher.locales
    end

    # Add the license translated content for the given language
    #
    # @param lang    [String] Language to add the translation to
    # @param content [String] Content to add
    #
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

    # @return [String] Product name
    attr_reader :product_name
  end
end
