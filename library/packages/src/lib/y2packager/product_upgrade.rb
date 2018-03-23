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

require "y2packager/product"

module Y2Packager
  # Evaluate the installed and available products and find the new upgraded
  # product tp install.
  class ProductUpgrade
    include Yast::Logger

    Yast.import "Pkg"

    # fallback mapping with upgraded products to handle some corner cases,
    # maps installed products to a new base product
    MAPPING = {
      # SLES12 + HPC module => SLESHPC15
      # (a bit tricky, the module became a new base product!)
      ["SLES", "sle-module-hpc"] => "SLES_HPC",
      # this is an internal product so far...
      ["SLE-HPC"]                => "SLES_HPC",
      # SLES11 => SLES15
      ["SUSE_SLES"]              => "SLES",
      # SLED11 => SLED15
      ["SUSE_SLED"]              => "SLED",
      # SLES4SAP11 => SLES4SAP15
      ["SUSE_SLES_SAP"]          => "SLES_SAP"
    }.freeze

    class << self
      # Find a new available base product which upgrades the installed base product.
      #
      # The workflow to find the new base product is:
      #
      #  1) If there is only one available base product then just use it,
      #     there are no other options than to upgrade to this product.
      #
      #  2) Let the solver to evaluate the product versions, their dependencies,
      #     Obsoletes/Provides, ... and find the correct upgrade candidate.
      #
      #     However, this step is quite fragile as the solver evaluates *all*
      #     packages, not just the products. That means the solver might fail
      #     because of some unrelated package dependency issue and cannot
      #     find the correct upgrade candidate. That's more likely when using
      #     custom or 3rd party packages.
      #
      #     If the solver fails then we try some fallback mechanisms for finding
      #     the new product.
      #
      #  3) Use a harcoded fallback mapping with the list of installed products
      #     mapped to a new base product product. The static mapping is needed to
      #     handle some corner cases properly. This includes product renames or
      #     changing a module to a base product.
      #
      #  4) As the last attempt try to find the installed base product in the
      #     available base products. It is very likely that SLES will be upgraded
      #     to SLES, SLED to SLED and so on.
      #
      #  If no candidate product is found then it returns nil. That should happen
      #  only when using completely incompatible products.
      #
      # @return [Y2Packager::Product,nil] the new upgraded product
      def new_base_product
        available = Y2Packager::Product.available_base_products
        return nil if available.empty?

        # just one product?
        product = find_by_count(available)
        return product if product

        # found by solver?
        product = find_by_solver
        return product if product

        # found by hardcoded mapping?
        product = find_by_mapping(available)
        return product if product

        # just 1:1 product upgrade?
        find_by_name(available)
      end

    private

      # check the count of the new base products
      # @param available [Array<Y2Packager::Product>] the available base products
      # @return [Y2Packager::Product,nil] the new upgraded product
      def find_by_count(available)
        return nil unless available.size == 1

        # only one base product available, we can upgrade only to this product
        log.info("Only one base product available: #{available.first}")
        available.first
      end

      # We do not know which available product might upgrade the installed product
      # if the installation medium contains several products.
      # Temporarily turn on the update mode to let the solver select the product for upgrade,
      # this will correctly handle possible product renames specified via Obsoletes/Provides.
      # @return [Y2Packager::Product,nil] the new upgraded product
      def find_by_solver
        # store the current resolvable states
        Yast::Pkg.SaveState

        # run the solver in the upgrade mode
        Yast::Pkg.PkgUpdateAll({})
        log_products

        product = Y2Packager::Product.selected_base
        # save the solver test case for easier debugging if no product upgrade was found
        Yast::Pkg.CreateSolverTestCase("/var/log/YaST2/solver-product-upgrade") unless product

        # restore the original resolvable states
        Yast::Pkg.RestoreState
        log_products

        log.info("Upgraded base product found by solver: #{product.inspect}")
        product
      end

      # find the upgrade product from the fallback mapping
      # @param available [Array<Y2Packager::Product>] the available base products
      # @return [Y2Packager::Product,nil] the new upgraded product
      def find_by_mapping(available)
        installed = Y2Packager::Product.installed_products

        # sort the keys by length, try more products first
        upgrade = MAPPING.keys.sort_by(&:size).find do |keys|
          keys.all? { |name| installed.any? { |p| p.name == name } }
        end

        log.info("Found fallback upgrade for products: #{upgrade.inspect}")
        return nil unless upgrade

        name = MAPPING[upgrade]
        product = available.find { |p| p.name == name }
        log.info("New product: #{product}")
        product
      end

      # find the upgrade product with the same identifier as the installed product
      # @param available [Array<Y2Packager::Product>] the available base products
      # @return [Y2Packager::Product,nil] the new upgraded product
      def find_by_name(available)
        installed_base = Y2Packager::Product.installed_base_product
        return nil unless installed_base

        product = available.find { |a| a.name == installed_base.name }
        log.info("New product: #{product}")
        product
      end

      # just a helper for logging the details for easier debugging
      def log_products
        products = Yast::Pkg.ResolvableProperties("", :product, "")
        log.debug("All products: #{products.inspect}")
        names = products.select { |p| p["status"] == :selected }.map { |p| p["name"] }
        log.info("Selected products: #{names.inspect}")
      end
    end
  end
end
