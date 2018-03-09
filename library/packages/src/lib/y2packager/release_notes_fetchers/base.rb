# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

module Y2Packager
  module ReleaseNotesFetchers
    # Base class for release notes fetchers
    #
    # A release note fetcher offers a mechanism to get release notes from a determined
    # source. If you want to define a new way of getting release notes for a given product,
    # you should define a class that inherits from this {Base} class and implements
    # its API.
    #
    # @see Rpm
    # @see Url
    class Base
      include Yast::Logger

      # @return [Product] Product to get release notes for
      attr_reader :product

      # Constructor
      #
      # @param product [Product] {Product} to get release notes for
      def initialize(product)
        @product = product
      end

      # Get release notes for the given product
      #
      # @param _prefs [ReleaseNotesContentPrefs] Content preferences
      # @return [String,nil] Release notes or nil if a release notes were not found
      #   (no package providing release notes or notes not found in the package)
      def release_notes(_prefs)
        raise NotImplementedError, "#release_notes not implemented"
      end

      # Return release notes latest version identifier
      #
      # @return [String,Symbol] Latest version identifier
      def latest_version
        raise NotImplementedError, "#latest_version not implemented"
      end
    end
  end
end
