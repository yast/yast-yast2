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
Yast.import "Language"
require "y2packager/product_reader"
require "y2packager/release_notes_reader"

module Y2Packager
  # Represent a product which is present in a repository. At this
  # time this class is responsible for finding out whether two
  # products instances are the same (for example, coming from different
  # repositories).
  class Product
    include Yast::Logger

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

    class << self
      # Return all known products
      #
      # @return [Array<Product>] Known products
      def all
        Y2Packager::ProductReader.new.all_products
      end

      # Return available base products
      #
      # @return [Array<Product>] Available base products
      def available_base_products
        Y2Packager::ProductReader.new.available_base_products
      end

      # Returns the selected base product
      #
      # It assumes that at most 1 base product can be selected.
      #
      # @return [Product] Selected base product
      def selected_base
        available_base_products.find(&:selected?)
      end

      # Return the products with a given status
      #
      # @param statuses [Array<Symbol>] Product status (:available, :installed, :selected, etc.)
      # @return [Array<Product>] Products with the given status
      def with_status(*statuses)
        all.select { |p| p.status?(*statuses) }
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

    # Return the license to confirm
    #
    # It will return the empty string ("") if the license does not exist or if
    # it was already confirmed.
    #
    # @return [String,nil] Product's license; nil if the product was not found.
    def license(lang = nil)
      license_lang = lang || Yast::Language.language
      Yast::Pkg.PrdGetLicenseToConfirm(name, license_lang)
    end

    # Determines whether the product has a license
    #
    # @return [Boolean] true if the product has a license
    def license?
      return false unless license
      license != ""
    end

    # Determine whether the license should be accepted or not
    #
    # @return [Boolean] true if the license acceptance is required
    def license_confirmation_required?
      Yast::Pkg.PrdNeedToAcceptLicense(name)
    end

    # Set license confirmation for the product
    #
    # @param confirmed [Boolean] determines whether the license should be accepted or not
    def license_confirmation=(confirmed)
      if confirmed
        Yast::Pkg.PrdMarkLicenseConfirmed(name)
      else
        Yast::Pkg.PrdMarkLicenseNotConfirmed(name)
      end
    end

    # Determine whether the license is confirmed
    #
    # @return [Boolean] true if the license was confirmed (or acceptance was not needed)
    def license_confirmed?
      Yast::Pkg.PrdHasLicenseConfirmed(name)
    end

    # Return product's release notes
    #
    # @param format    [Symbol] Release notes format (use :txt as default)
    # @param user_lang [String] Preferred language (use current language as default)
    # @return [ReleaseNotes] Release notes for product, language and format
    # @see ReleaseNotesReader
    # @see ReleaseNotes
    def release_notes(format = :txt, user_lang = Yast::Language.language)
      ReleaseNotesReader.new(self).release_notes(user_lang: user_lang, format: format)
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
      Yast::Pkg.ResolvableProperties(name, :product, "").any? do |res|
        statuses.include?(res["status"])
      end
    end
  end
end
