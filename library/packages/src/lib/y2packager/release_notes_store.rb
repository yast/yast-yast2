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

require "yast"
require "y2packager/product"

module Y2Packager
  # Release notes store
  class ReleaseNotesStore
    class << self
      def current
        @current ||= new
      end
    end

    # Constructor
    def initialize
      @release_notes = {}
    end

    # Retrieve release notes for a given product, lang, format and version
    #
    # @param product_name [String] Product name
    # @param user_lang    [String] Language asked by user
    # @param format       [Symbol] Symbol
    # @param version      [String,Symbol] Release note version (or :latest)
    # @return [ReleaseNotes] Release notes matching given criteria
    def retrieve(product_name, user_lang, format, version)
      rn = release_notes[product_name]
      return nil if rn.nil?
      rn.matches?(user_lang, format, version) ? rn : nil
    end

    # Store release notes for later retrieval
    #
    # @param rn [ReleaseNotes] Release notes to store
    def store(rn)
      release_notes[rn.product_name] = rn
    end

    # Clear store
    def clear
      release_notes.clear
    end

  private

    # @return [Hash<String,ReleaseNotes>] Map containing relation between
    #   product names and release notes.
    attr_reader :release_notes
  end
end
