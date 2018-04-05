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

module Y2Packager
  module LicensesHandlers
    # Base class for licenses handlers
    class Base
      include Yast::Logger

      # @return [String] Product name to handle license status
      attr_reader :product_name

      # Constructor
      #
      # @param product_name [String] Product name to handle license status
      def initialize(product_name)
        @product_name = product_name
      end
    end
  end
end

