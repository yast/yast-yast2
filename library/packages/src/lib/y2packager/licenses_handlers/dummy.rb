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

module Y2Packager
  module LicensesHandlers
    class Dummy
      attr_reader :product_name

      # Constructor
      #
      # @param product_name [String] Product's name
      def initialize(product_name)
        @product_name = product_name
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def license_confirmation_required?
      end

      # Set the license confirmation for the product
      #
      # @param confirmed [Boolean] true if it should be accepted; false otherwise
      def license_confirmation=(confirmed)
      end
    end
  end
end
