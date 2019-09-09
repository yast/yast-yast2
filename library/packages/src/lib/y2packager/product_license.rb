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
require "forwardable"
require "y2packager/license"

module Y2Packager
  # This class holds the license stuff for a given product
  #
  # Why a separate ProductLicense class? First of all, we wanted to extract
  # the license handling from Y2Packager::Product and moving this logic to
  # Y2Packager::License was not a good idea because different products could
  # share the same license. Additionally, this class offers an API to work
  # with licenses when a proper Product or Addon object is not available
  # (backward compatibility reasons).
  #
  # @see Y2Packager::Product
  # @see Y2Packager::License
  class ProductLicense
    extend Forwardable

    def_delegators :@license, :content_for, :locales

    # @!method license_confirmation_required?
    #   Determine whether the license should be accepted or not
    #   @return [Boolean] true if the license acceptance is required
    def_delegator :@fetcher, :confirmation_required?

    # @!method license_confirmation=(confirmed)
    #   Set the license confirmation for the product
    #   @param confirmed [Boolean] true if it should be accepted; false otherwise
    def_delegator :@handler, :confirmation=

    # @return [License] Product's license
    attr_reader :license

    class << self
      # Find license for a given product
      #
      # This method uses a cache to return an already fetched product license.
      #
      # @param product_name [String] Product's name
      #
      # @return [ProductLicense]
      def find(product_name, content: nil)
        return cache[product_name] if cache[product_name]

        license = License.find(product_name, content: content)
        return nil unless license

        cache[product_name] = ProductLicense.new(product_name, license)
      end

      # Clear product licenses cache
      def clear_cache
        @cache = nil
      end

      private def cache
        @cache ||= {}
      end
    end

    # Constructor
    #
    # @param product_name [String]
    # @param license [Yast::License]
    def initialize(product_name, license)
      @product_name = product_name
      @license = license
      @handler = license.handler
      @fetcher = license.fetcher
    end

    # Determine whether the license have been accepted or not
    #
    # @return [Boolean] true if the license has been accepted; false otherwise.
    def accepted?
      sync_acceptance
      license.accepted?
    end

    # Accept the license
    #
    # As a side effect, it will update the license acceptance
    def accept!
      license.accept!
      sync_acceptance
      nil
    end

    # Reject the license
    def reject!
      license.reject!
      sync_acceptance
      nil
    end

  private

    def sync_acceptance
      return @handler unless @handler

      @handler.confirmation = license.accepted?
    end
  end
end
