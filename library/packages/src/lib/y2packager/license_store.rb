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

require "singleton"

module Y2Packager
  # This class is responsible for storing the relation between products and
  # licenses. A license could be the same for multiple products and it is
  # determined by the license id.
  class LicenseStore
    include Singleton

    attr_reader :product_licenses

    # Constructor
    def initialize
      @product_licenses = {}
    end

    # Return the license for the given product name
    #
    # @return [License,nil]
    def license_for(product_name)
      @product_licenses[product_name]
    end

    # Stores the given license for the given product name if there is not
    # already a license with the same id. In case that there is already a
    # license with the same id that license is used and returned instead.
    #
    # @param product_name [String]
    # @param license [License]
    # @return [License] The given license or the already stored one with the
    # same id.
    def add_license_for(product_name, license)
      log.info "Adding license for #{product_name}"
      stored_license = license(license.id)

      @product_licenses[product_name] = stored_license || license
    end

  private

    # Looks for a license with the given id
    #
    # @param id [String] of the license to be found
    # @return [License, nil] a license with the given id or nil if not found
    def license(id)
      @product_licenses.values.find { |l| l.id == id }
    end
  end
end
