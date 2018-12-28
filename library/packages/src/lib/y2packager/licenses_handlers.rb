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

require "y2packager/licenses_handlers/libzypp"
require "y2packager/licenses_handlers/rpm"

module Y2Packager
  # This module contains licenses handlers
  #
  # Licenses can be retrieved from different places (libzypp, URLs, etc.). The
  # classes defined in this module are able to interact with these sources in
  # order to find out, for instance, whether a license must be accepted.
  module LicensesHandlers
    # Return the proper license handler based on given fetcher
    #
    # @param fetcher      [LicensesFetchers::Base] Fetcher used as source to fetch license
    # @param product_name [String]                 Product's name
    #
    # @return [Object]
    def self.for(fetcher, product_name)
      type = fetcher.class.name.split("::").last
      klass = const_get(type.to_s.capitalize)

      klass.new(product_name)
    end
  end
end
