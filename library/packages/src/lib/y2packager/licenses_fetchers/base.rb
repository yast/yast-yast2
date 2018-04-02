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
require "y2packager/license"

Yast.import "Pkg"

module Y2Packager
  module LicensesFetchers
    # Base class for licenses fetchers
    class Base
      include Yast::Logger

      # @return [String] Product name to get licenses for
      attr_reader :product_name

      # Constructor
      #
      # @param product_name [String] to get licenses for
      def initialize(product_name)
        @product_name = product_name
      end
    end
  end
end
