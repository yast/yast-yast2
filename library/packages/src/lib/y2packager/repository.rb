# typed: true
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

require "y2packager/zypp_url"
require "y2packager/product"
require "y2packager/resolvable"

module Y2Packager
  # This class represents a libzypp repository
  #
  # It offers a simple API to list them, query basic attributes,
  # find out the products they offer and enabling/disabling them.
  #
  # @example Get all repositories
  #   all_repos = Y2Packager::Repository.all     #=> [#<Y2Packager::Repository>, ...]
  #   enabled = Y2Packager::Repository.enabled   #=> [#<Y2Packager::Repository>]
  #
  # @example Get a repository using a repo ID
  #   repo = Y2Packager::Repository.find(1) #=> #<Y2Packager::Repository>
  #   repo.autorefresh?                   #=> true
  #   repo.url                            #=> "http://download.opensuse.org..."
  #
  # @example Disabling a repository
  #   repo = Y2Packager::Repository.find(1) #=> #<Y2Packager::Repository>
  #   repo.enabled?                       #=> true
  #   repo.disabled!
  #   repo.enabled?                       #=> false
  class Repository
    Yast.import "Pkg"

    # @return [Fixnum] Repository ID
    attr_reader :repo_id
    # @return [String] Repository name
    attr_reader :name
    # @return [ZyppUrl] Repository URL
    attr_reader :raw_url
    # @return [String] Product directory
    attr_reader :product_dir
    # @return [String] Repository alias
    attr_reader :repo_alias

    attr_writer :enabled
    private :enabled=

    # Repository was not found
    class NotFound < StandardError; end

    class << self
      # Return all registered repositories
      #
      # @param enabled_only [Boolean] Returns only enabled repositories
      # @return [Array<Repository>] Array containing all repositories
      #
      # @see Yast::Pkg.SourceGetCurrent
      # @see Y2Packager::Repository.find
      def all(enabled_only: false)
        Yast::Pkg.SourceGetCurrent(enabled_only).map do |repo_id|
          find(repo_id)
        end
      end

      # Return only enabled repositories
      #
      # @return [Array<Repository>] Array containing enabled repositories
      def enabled
        all.select(&:enabled?)
      end

      # Return only disabled repositories
      #
      # @return [Array<Repository>] Array containing disabled repositories
      def disabled
        all.reject(&:enabled?)
      end

      # Return a repository with the given repo_id
      #
      # @param repo_id [Fixnum] Repository ID
      # @return [Y2Packager::Repository] Repository instance
      #
      # @raise NotFound
      def find(repo_id)
        repo_data = Yast::Pkg.SourceGeneralData(repo_id)
        raise NotFound if repo_data.nil?

        new(repo_id: repo_id, repo_alias: repo_data["alias"], enabled: repo_data["enabled"],
          name: repo_data["name"], autorefresh: repo_data["autorefresh"],
          url: repo_data["raw_url"], product_dir: repo_data["product_dir"])
      end

      # Add a repository
      #
      # @param name        [String]       Name
      # @param url         [URI::Generic, ZyppUrl] Repository URL
      # @param product_dir [String]       Product directory
      # @param enabled     [Boolean]      Is the repository enabled?
      # @param autorefresh [Boolean]      Is auto-refresh enabled for this repository?
      # @return [Y2Packager::Repository,nil] New repository or nil if creation failed
      def create(name:, url:, product_dir: "", enabled: true, autorefresh: true)
        repo_id = Yast::Pkg.RepositoryAdd(
          "name" => name, "base_urls" => [url.to_s], "enabled" => enabled,
          "autorefresh" => autorefresh, "prod_dir" => product_dir
        )

        repo_id ? find(repo_id) : nil
      end
    end

    # Constructor
    #
    # @note This class calculates the expanded URL ({#url}) out of the unexpanded version
    # ({#raw_url}), so there is no need to provide both versions in the constructor. Still,
    # both `:url` and `:raw_url` are accepted for backwards compatibility. If `:raw_url`
    # is provided, `:url` will be ignored (it can be calculated at any point).
    #
    # @param repo_alias  [String]       Repository alias (unique identifier)
    # @param repo_id     [Fixnum]       Repository ID
    # @param name        [String]       Name
    # @param url         [URI::Generic, ZyppUrl] Repository URL
    # @param raw_url     [URI::Generic, ZyppUrl] Optional raw repository URL
    # @param product_dir [String]       Product directory
    # @param enabled     [Boolean]      Is the repository enabled?
    # @param autorefresh [Boolean]      Is auto-refresh enabled for this repository?
    def initialize(repo_id:, repo_alias:, name:, url:, raw_url: nil, product_dir: "", enabled:, autorefresh:)
      @repo_id = repo_id
      @repo_alias = repo_alias
      @name    = name
      @enabled = enabled
      @autorefresh = autorefresh
      @raw_url = ZyppUrl.new(raw_url || url)
      @product_dir = product_dir
    end

    # Return repository scheme
    #
    # The scheme is determined using the URL
    #
    # @return [Symbol,nil] URL scheme, nil if the URL is not defined
    def scheme
      raw_url&.scheme&.to_sym
    end

    # Return products contained in the repository
    #
    # @return [Array<Y2Packager::Product>] Products in the repository
    #
    # @see Y2Packager::Product
    def products
      return @products if @products

      # Filter products from this repository
      candidates = Y2Packager::Resolvable.find(kind: :product, source: repo_id)

      # Build an array of Y2Packager::Product objects
      @products = candidates.map do |data|
        Y2Packager::Product.new(name: data.name, version: data.version,
          arch: data.arch, category: data.category, vendor: data.vendor)
      end
    end

    # Determine if the repository is local
    #
    # @return [Boolean] true if the repository is considered local; false otherwise
    def local?
      raw_url.local?
    end

    # Repository URL, expanded version (ie. with the repository variables already
    # replaced by their values)
    #
    # @return [ZyppUrl]
    def url
      raw_url.expanded
    end

    # Determine if the repository is enabled
    #
    # @return [Boolean] true if repository is enabled; false otherwise
    def enabled?
      @enabled
    end

    # Determine if auto-refresh is enabled for the repository
    #
    # @return [Boolean] true if auto-refresh is enabled; false otherwise
    def autorefresh?
      @autorefresh
    end

    # Return addons in the repository
    #
    # @return [Array<Y2Packager::Product>] Addons in the repository
    #
    # @see #products
    def addons
      products.select { |p| p.category == :addon }
    end

    # Enable the repository
    #
    # The repository status will be stored only in memory. Calling to
    # Yast::Pkg.SourceSaveAll will make it persistent.
    #
    # @return [Boolean] true on success, false otherwise
    #
    # @see Yast::Pkg.SourceSetEnabled
    # @see Yast::Pkg.SourceSaveAll
    def enable!
      return false unless Yast::Pkg.SourceSetEnabled(repo_id, true)

      self.enabled = true
      true
    end

    # Disable the repository
    #
    # The repository status will be stored only in memory. Calling to
    # Yast::Pkg.SourceSaveAll will make it persistent.
    #
    # @return [Boolean] true on success, false otherwise
    #
    # @see Yast::Pkg.SourceSetEnabled
    # @see Yast::Pkg.SourceSaveAll
    def disable!
      return false unless Yast::Pkg.SourceSetEnabled(repo_id, false)

      self.enabled = false
      true
    end

    # Remove the repository, the repo_id is set to `nil` after removal.
    #
    # The repository will be removed only in memory. Calling to
    # Yast::Pkg.SourceSaveAll will make the removal persistent.
    #
    # @return [Boolean] true on success, false otherwise
    #
    # @see Yast::Pkg.SourceDelete
    # @see Yast::Pkg.SourceSaveAll
    def delete!
      return false unless Yast::Pkg.SourceDelete(repo_id)

      @repo_id = nil
      true
    end

    # Change the repository URL
    #
    # The URL will be changed only in memory. Calling to
    # Yast::Pkg.SourceSaveAll will make the change persistent.
    #
    # @param new_url [String,ZyppUrl] the new URL (with unexpanded variables)
    def raw_url=(new_url)
      return unless Yast::Pkg.SourceChangeUrl(repo_id, new_url.to_s)

      @raw_url = ZyppUrl.new(new_url)
    end

    alias_method :url=, :raw_url=
  end
end
