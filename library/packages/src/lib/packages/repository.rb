require "uri"
require "packages/product"

module Packages
  # This class represents a libzypp repository
  #
  # It offers a simple API to list them, query basic attributes,
  # find out the products they offer and enabling/disabling them.
  #
  # @example Get all repositories
  #   all_repos = Packages::Repository.all     #=> [#<Packages::Repository>, ...]
  #   enabled = Packages::Repository.enabled   #=> [#<Packages::Repository>]
  #
  # @example Get a repository using a repo ID
  #   repo = Packages::Repository.find(1) #=> #<Packages::Repository>
  #   repo.autorefresh?                   #=> true
  #   repo.url                            #=> "http://download.opensuse.org..."
  #
  # @example Disabling a repository
  #   repo = Packages::Repository.find(1) #=> #<Packages::Repository>
  #   repo.enabled?                       #=> true
  #   repo.disabled!
  #   repo.enabled?                       #=> false
  class Repository
    Yast.import "Pkg"

    # Repository schemes considered local (see #local?)
    # https://github.com/openSUSE/libzypp/blob/a7a038aeda1ad6d9e441e7d3755612aa83320dce/zypp/Url.cc#L458
    LOCAL_SCHEMES = [:cd, :dvd, :dir, :hd, :iso, :file].freeze

    # @return [Fixnum] Repository ID
    attr_reader :repo_id
    # @return [String] Repository name
    attr_reader :name
    # @return [URI::Generic] Repository URL
    attr_reader :url

    attr_writer :enabled
    private :enabled=

    # Repository was not found
    class NotFound < StandardError; end

    class << self
      # Return all registered repositories
      #
      # @return [Array<Repository>] Array containing all repositories
      #
      # @see Yast::Pkg.SourceGetCurrent
      # @see Packages::Repository.find
      def all
        Yast::Pkg.SourceGetCurrent(false).map do |repo_id|
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
      # @return [Packages::Repository] Repository instance
      #
      # @raise NotFound
      def find(repo_id)
        repo_data = Yast::Pkg.SourceGeneralData(repo_id)
        raise NotFound if repo_data.nil?
        new(repo_id: repo_id, enabled: repo_data["enabled"],
          name: repo_data["name"], autorefresh: repo_data["autorefresh"],
          url: URI(repo_data["url"]))
      end
    end

    # Constructor
    #
    # @param repo_id     [Fixnum]       Repository ID
    # @param name        [String]       Name
    # @param enabled     [Boolean]      Is the repository enabled?
    # @param autorefresh [Boolean]      Is auto-refresh enabled for this repository?
    # @param url         [URI::Generic] Repository URL
    def initialize(repo_id:, name:, enabled:, autorefresh:, url:)
      @repo_id = repo_id
      @name    = name
      @enabled = enabled
      @autorefresh = autorefresh
      @url = url
    end

    # Return repository scheme
    #
    # The scheme is determined using the URL
    #
    # @return [Symbol,nil] URL scheme
    def scheme
      url.scheme ? url.scheme.to_sym : nil
    end

    # Return products contained in the repository
    #
    # @return [Array<Packages::Product>] Products in the repository
    #
    # @see Yast::Pkg.ResolvableProperties
    # @see Packages::Product
    def products
      return @products unless @products.nil?

      # Filter products from this repository
      candidates = Yast::Pkg.ResolvableProperties("", :product, "").select do |pro|
        pro["source"] == repo_id
      end

      # Build an array of Packages::Product objects
      @products = candidates.map do |data|
        Packages::Product.new(name: data["name"], version: data["version"],
          arch: data["arch"], category: data["category"], status: data["status"],
          vendor: data["vendor"])
      end
    end

    # Determine if the repository is local
    #
    # @return [Boolean] true if the repository is considered local; false otherwise
    def local?
      LOCAL_SCHEMES.include?(scheme)
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
    # @return [Array<Packages::Product>] Addons in the repository
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
    # @see Yast::Pkg.SourceSetEnabled
    # @see Yast::Pkg.SourceSaveAll
    def enable!
      success = Yast::Pkg.SourceSetEnabled(repo_id, true)
      success && self.enabled = true
    end

    # Disable the repository
    #
    # The repository status will be stored only in memory. Calling to
    # Yast::Pkg.SourceSaveAll will make it persistent.
    #
    # @see Yast::Pkg.SourceSetEnabled
    # @see Yast::Pkg.SourceSaveAll
    def disable!
      success = Yast::Pkg.SourceSetEnabled(repo_id, false)
      success && self.enabled = false
    end
  end
end
