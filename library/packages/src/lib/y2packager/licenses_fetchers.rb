# typed: true
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
require "y2packager/licenses_fetchers/libzypp"
require "y2packager/licenses_fetchers/rpm"

module Y2Packager
  # This module contains licenses fetchers
  #
  # Licenses can be retrieved from different places (libzypp, URLs, etc.). The classes defined in
  # this module are able to retrieve licenses contents.
  module LicensesFetchers
    include Yast::Logger

    # Candidate sources to retrieve the license content. Note that order matters because it will be
    # chosen the first source able to fetch the content.
    KNOWN_SOURCES = [:libzypp, :rpm].freeze

    # Return the proper license fetcher
    #
    # @param product_name [String] Product's name
    #
    # @return [Object, nil] The first valid fetcher found or nil
    def self.for(product_name)
      KNOWN_SOURCES.each do |source|
        log.info "Looking a license source for #{product_name} from #{source}"

        klass = const_get(source.to_s.capitalize)
        fetcher = klass.new(product_name)

        return fetcher if fetcher.found?
      end

      nil
    end
  end
end
