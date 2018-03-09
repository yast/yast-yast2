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

module Y2Packager
  # Release notes for a given product
  #
  # This class stores the content and some additional metadata about release
  # notes for a given product.
  class ReleaseNotes
    # @return [String] Product name (internal libzypp name)
    attr_reader :product_name
    # @return [String] Release notes content
    attr_reader :content
    # @return [String] Language asked by user
    attr_reader :user_lang
    # @return [String] Contents language
    attr_reader :lang
    # @return [Symbol] Contents format
    attr_reader :format
    # @return [String] Release notes version (from release notes package)
    attr_reader :version

    # Constructor
    #
    # @param product_name [String] Product name (internal libzypp name)
    # @param content      [String] Release notes content
    # @param user_lang    [String] Language asked by user
    # @param lang         [String] Contents language
    # @param format       [Symbol] Contents format
    # @param version      [String] Release notes version (from release notes package)
    def initialize(product_name:, content:, user_lang:, lang:, format:, version:)
      @product_name = product_name
      @content = content
      @user_lang = user_lang
      @lang = lang
      @version = version
      @format = format
    end

    # Determine whether a release notes matches language, format and version requirements
    #
    # @param user_lang    [String] Language asked by user
    # @param format       [Symbol] Symbol
    # @param version      [String] Release note's version
    # @return [Boolean] true if it matches; false otherwise.
    def matches?(user_lang, format, version)
      self.user_lang == user_lang && self.format == format &&
        (self.version == version || self.version == :latest)
    end
  end
end
