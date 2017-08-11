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

module Packages
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
    # @return [Symbol] Status
    attr_reader :status
    # @return [Symbol] Category
    attr_reader :category
    # @return [String] Vendor
    attr_reader :vendor
    # @return [Integer] Display order
    attr_reader :order
    # package including installation.xml for install on top of lean os
    attr_accessor :installation_package

    # Constructor
    #
    # @param name         [String]  Name
    # @param short_name   [String]  Short name
    # @param display_name [String]  Display name
    # @param version      [String]  Version
    # @param arch         [String]  Architecture
    # @param status       [Symbol]  Status (:selected, :removed, :installed, :available)
    # @param category     [Symbol]  Category (:base, :addon)
    # @param vendor       [String]  Vendor
    # @param repo_id      [Integer] Repository ID
    # @param order        [Integer] Display order
    # @param package      [String]  Installation package name
    def initialize(name: nil, short_name: nil, display_name: nil, version: nil, arch: nil, status: nil,
      category: nil, vendor: nil, order: nil, installation_package: nil)
      @name = name
      @short_name = short_name
      @display_name = display_name
      @version = version
      @arch = arch.to_sym if arch
      @status = status.to_sym if status
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
    # @return [Boolean] true if it is selected
    def selected?
      Yast::Pkg.ResolvableProperties(name, :product, "").any? do |res|
        res["status"] == :selected
      end
    end

    # select the product to install
    # @return [Boolean] true if the product has been sucessfully selected
    def select
      log.info "Selecting product #{name} to install"
      Yast::Pkg.ResolvableInstall(name, :product, "")
    end

    # Return a package label
    #
    # It will use 'display_name', 'short_name' or 'name'.
    #
    # @return [String] Package label
    def label
      display_name || short_name || name
    end
  end
end
