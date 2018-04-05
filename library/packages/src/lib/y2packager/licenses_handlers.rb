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

require "y2packager/licenses_handlers/rpm"
require "y2packager/licenses_handlers/dummy"

module Y2Packager
  module LicensesHandlers
    # Return the licenses proper fetcher for a given source
    #
    # @param source [Symbol] :rpm or :url
    def self.for(source, product_name)
      klass = const_get(source.to_s.capitalize)
      klass.new(product_name)
    end
  end
end
