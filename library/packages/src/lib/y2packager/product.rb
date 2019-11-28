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

Yast.import "Pkg"
require "y2packager/product_reader"
require "y2packager/release_notes_reader"
require "y2packager/product_license_mixin"
require "y2packager/resolvable"

module Y2Packager
  # Represent a product which is present in a repository. At this
  # time this class is responsible for finding out whether two
  # products instances are the same (for example, coming from different
  # repositories).
  class Product
    include Yast::Logger
    include ProductLicenseMixin

    # @return [String] Name
    attr_reader :name
    # @return [String] Short name
    attr_reader :short_name
    # @return [String] Display name
    attr_reader :display_name
    # @return [String] Version
    attr_reader :version
    # @return [String] Architecture
    attr_reader :arch
    # @return [Symbol] Category
    attr_reader :category
    # @return [String] Vendor
    attr_reader :vendor
    # @return [Integer] Display order
    attr_reader :order
    # @return [String] package including installation.xml for install on top of lean os
    attr_reader :installation_package
    # @return [Integer] repository for the installation_package
    attr_reader :installation_package_repo

    class << self
      PKG_BINDINGS_ATTRS = ["name", "short_name", "display_name", "version", "arch",
                            "category", "vendor"].freeze

      # Resets cached attributes of the class
      #
      # @return [true]
      def reset
        @forced_base_product = nil
      end

      # Create a product from pkg-bindings hash data.
      # @param product [Hash] the pkg-bindings product hash
      # @return [Y2Packager::Product] converted product
      def from_h(product)
        params = PKG_BINDINGS_ATTRS.each_with_object({}) { |a, h| h[a.to_sym] = product[a] }
        Y2Packager::Product.new(params)
      end

      # Create a product from Y2Packager::Resolvable
      # @param product [Y2Packager::Resolvable] product
      # @param installation_package [String] installation package name
      # @param displayorder [Integer] display order from the package provides
      # @return [Y2Packager::Product] converted product
      def from_resolvable(product, installation_package = "",
        displayorder = nil)
        Y2Packager::Product.new(
          name: product.name, short_name: product.short_name,
          display_name: product.display_name, version: product.version,
          arch: product.arch, category: product.category,
          vendor: product.vendor, order: displayorder,
          installation_package: installation_package
        )
      end

      # Return all known available products
      #
      # @return [Array<Product>] Known available products
      def all
        Y2Packager::ProductReader.new.all_products
      end

      # Return available base products
      #
      # @return [Array<Product>] Available base products
      def available_base_products
        Y2Packager::ProductReader.new.available_base_products
      end

      # Return the installed base product
      #
      # @return [Product,nil] Installed base product or nil if not found
      def installed_base_product
        Y2Packager::ProductReader.new.installed_base_product
      end

      # Return all installed products (including the base product)
      #
      # @return [Product,nil] Installed products
      def installed_products
        Y2Packager::ProductReader.new.all_installed_products
      end

      # Returns the selected base product
      #
      # It assumes that at most 1 base product can be selected.
      #
      # @return [Product] Selected base product
      def selected_base
        products = Y2Packager::ProductReader.new.available_base_products(force_repos: true)
        selected = products.find(&:selected?)
        selected ||= products.first
        selected
      end

      # Return the products with a given status
      #
      # @param statuses [Array<Symbol>] Product status (:available, :installed, :selected, etc.)
      # @return [Array<Product>] Products with the given status
      def with_status(*statuses)
        all.select { |p| p.status?(*statuses) }
      end

      # Returns, if any, the base product which must be selected
      #
      # A base product can be forced to be selected through the `select_product`
      # element in the software section of the control.xml file (bsc#1124590,
      # bsc#1143943).
      #
      # @return [Y2Packager::Product, nil] the forced base product or nil when
      # either, it wasn't selected or the selected wasn't found among the
      # available ones.
      def forced_base_product
        Yast.import "ProductFeatures"

        return @forced_base_product if @forced_base_product

        forced_product_name = Yast::ProductFeatures.GetStringFeature("software", "select_product")
        return if forced_product_name.to_s.empty?

        @forced_base_product = available_base_products.find { |p| p.name == forced_product_name }
      end
    end

    # Constructor
    #
    # @param name                 [String]  Name
    # @param short_name           [String]  Short name
    # @param display_name         [String]  Display name
    # @param version              [String]  Version
    # @param arch                 [String]  Architecture
    # @param category             [Symbol]  Category (:base, :addon)
    # @param vendor               [String]  Vendor
    # @param order                [Integer] Display order
    # @param installation_package [String]  Installation package name
    def initialize(name: nil, short_name: nil, display_name: nil, version: nil, arch: nil,
      category: nil, vendor: nil, order: nil, installation_package: nil)
      @name = name
      @short_name = short_name
      @display_name = display_name
      @version = version
      @arch = arch.to_sym if arch
      @category = category.to_sym if category
      @vendor = vendor
      @order = order
      @installation_package = installation_package
    end

    # Compare two different products
    #
    # If arch, name, version and vendor match they are considered the
    # same product.
    #
    # @return [Boolean] true if both products are the same; false otherwise
    def ==(other)
      result = arch == other.arch && name == other.name &&
        version == other.version && vendor == other.vendor
      log.info("Comparing products: '#{arch}' <=> '#{other.arch}', '#{name}' <=> '#{other.name}', "\
        "'#{version}' <=> '#{other.version}', '#{vendor}' <=> '#{other.vendor}' => "\
        "result: #{result}")
      result
    end

    # is the product selected to install?
    #
    # Only the 'name' will be used to find out whether the product is selected,
    # ignoring the architecture, version, vendor or any other property. libzypp
    # will take care of finding the proper product.
    #
    # @return [Boolean] true if it is selected
    def selected?
      status?(:selected)
    end

    # is the product selected to install?
    #
    # Only the 'name' will be used to find out whether the product is installed,
    # ignoring the architecture, version, vendor or any other property. libzypp
    # will take care of finding the proper product.
    #
    # @see #status?
    # @return [Boolean] true if it is installed
    def installed?
      status?(:installed)
    end

    # select the product to install
    #
    # Only the 'name' will be used to select the product, ignoring the
    # architecture, version, vendor or any other property. libzypp will take
    # care of selecting the proper product.
    #
    # @return [Boolean] true if the product has been sucessfully selected
    def select
      log.info "Selecting product #{name} to install"
      Yast::Pkg.ResolvableInstall(name, :product, "")
    end

    # Restore the status of a product
    #
    # Only the 'name' will be used to restore the product status, ignoring the
    # architecture, version, vendor or any other property. libzypp will take
    # care of modifying the proper product.
    #
    def restore
      log.info "Restoring product #{name} status"
      Yast::Pkg.ResolvableNeutral(name, :product, true)
    end

    # Return a package label
    #
    # It will use 'display_name', 'short_name' or 'name'.
    #
    # @return [String] Package label
    def label
      display_name || short_name || name
    end

    # Return product's release notes
    #
    # @param format    [Symbol] Release notes format (use :txt as default)
    # @param user_lang [String] Preferred language (use current language as default)
    # @return [ReleaseNotes] Release notes for product, language and format
    # @see ReleaseNotesReader
    # @see ReleaseNotes
    def release_notes(user_lang, format = :txt)
      ReleaseNotesReader.new(self).release_notes(user_lang: user_lang, format: format)
    end

    # Return release notes URL
    #
    # Release notes might not be defined in libzypp and this method returns the URL
    # to get release notes from.
    #
    # @return [String,nil] Release notes URL or nil if it is not defined.
    def relnotes_url
      return nil unless resolvable_properties

      url = resolvable_properties.relnotes_url
      url.empty? ? nil : url
    end

    # Determine whether a product is in a given status
    #
    # Only the 'name' will be used to find out whether the product status,
    # ignoring the architecture, version, vendor or any other property. libzypp
    # will take care of finding the proper product.
    #
    # @param statuses [Array<Symbol>] Status to compare with.
    # @return [Boolean] true if it is in the given status
    def status?(*statuses)
      Y2Packager::Resolvable.find(kind: :product, name: name).any? do |res|
        statuses.include?(res.status)
      end
    end

    # Return product's resolvable properties
    #
    # Only the 'name' and 'version' will be used to find out the product
    # properties, ignoring the architecture, vendor or any other property.
    # libzypp will take care of finding the proper product.
    #
    # @return [Hash] properties
    def resolvable_properties
      @resolvable_properties ||= Y2Packager::Resolvable.find(kind: :product, name: name, version: version).first
    end
  end
end
