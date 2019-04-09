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

    # mapping with upgraded products to handle some corner cases,
    # maps installed products to a new available base product
    MAPPING = {
      # SLES12 + HPC module => SLESHPC15
      # (a bit tricky, the module became a new base product!)
      ["SLES", "sle-module-hpc"] => "SLE_HPC",
      ["SLES", "SUSE-Manager-Proxy"] => "SUSE-Manager-Proxy",
      # this is an internal product so far...
      ["SLE-HPC"]                => "SLE_HPC",
      # SLES11 => SLES15
      ["SUSE_SLES"]              => "SLES",
      # SLED11 => SLED15
      ["SUSE_SLED"]              => "SLED",
      # SLES4SAP11 => SLES4SAP15
      ["SUSE_SLES_SAP"]          => "SLES_SAP",
      # (installed) openSUSE => (available) SLES,
      # this one is used when openSUSE is not available, e.g. booting SLE medium
      # (moreover the openSUSE medium should contain only one product so that
      # product should be used unconditionally)
      ["openSUSE"]               => "SLES"
    }.freeze

    class << self
      # Find a new available base product which upgrades the installed base product.
      #
      # The workflow to find the new base product is:
      #
      #  1) If there is only one available base product then just use it,
      #     there are no other options than to upgrade to this product.
      #
      #  2) TODO: Somehow evaluate the available and installed products and
      #     find the best upgrade candidate.
      #
      #     Note: We cannot use the solver here because it evaluates *all*
      #     packages, not just the products. Moreover some products
      #     (modules/extensions) might be added later which could change
      #     the best upgrade candidate.
      #
      #  3) Use a harcoded mapping with the list of installed products
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

        # found by hardcoded mapping?
        product = find_by_mapping(available)
        return product if product

        # just 1:1 product upgrade?
        find_by_name(available)
      end

      # Returns the product name which obsoletes the given product.
      # @param old_product_name <String> Product name which will be obsoleted
      # @return [<String>] Product names which obsoletes this product.
      def will_be_obsolated_by(old_product_name)
        installed = Y2Packager::Product.installed_products.map { |p| p.name }
        MAPPING.each_with_object([]) do |(products,obsolated_by),a|
          if products.include?(old_product_name) &&
            (installed & products) == products # All products are installed
            a << obsolated_by
          end
        end
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

      # find the upgrade product from the fallback mapping
      # @param available [Array<Y2Packager::Product>] the available base products
      # @return [Y2Packager::Product,nil] the new upgraded product
      def find_by_mapping(available)
        installed = Y2Packager::Product.installed_products

        # sort the keys by length, try more products first
        # to find the most specific upgrade, prefer the
        # SLES + sle-module-hpc => SLE_HPC upgrade to plain SLES => SLES upgrade
        # (if that would be in the list)
        upgrade = MAPPING.keys.sort_by(&:size).find do |keys|
          keys.all? { |name| installed.any? { |p| p.name == name } }
        end

        log.info("Fallback upgrade for products: #{upgrade.inspect}")
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
