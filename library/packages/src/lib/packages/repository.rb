require "uri"
require "packages/repository_product"

module Packages
  class Repository
    Yast.import "Pkg"
    
    # @return [Fixnum] Repository ID
    attr_reader :repo_id
    # @return [String] Repository name
    attr_reader :name
    # @return [URI::Generic] Repository URL
    attr_reader :url

    # Repository was not found
    class NotFound < StandardError; end

    class << self
      # Return all registered repositories
      #
      # @see Yast::Pkg.SourceGetCurrent
      # @see Packages::Repository.find
      def all
        Yast::Pkg.SourceGetCurrent(true).map do |repo_id|
          find(repo_id)
        end
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
      @url     = url
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
    # @return [Array<Packages::RepositoryProduct>] Products in the repository
    #
    # @see Yast::Pkg.ResolvableProperties
    # @see Packages::RepositoryProduct
    def products
      return @products unless @products.nil?

      # Filter products from this repository
      candidates = Yast::Pkg.ResolvableProperties("", :product, "").select do |pro|
        pro["source"] == repo_id
      end
      
      # Build an array of Packages::Product objects
      @products = candidates.map do |data|
        Packages::RepositoryProduct.new(name: data["name"], version: data["version"],
          arch: data["arch"], category: data["category"], status: data["status"],
          vendor: data["vendor"])
      end
    end

    # Determine if repository is enabled
    #
    # @return [Boolean] true if repository is enabled; false otherwise
    def enabled?
      @enabled
    end

    # Determine if auto-refresh is enabled
    #
    # @return [Boolean] true if auto-refresh is enabled; false otherwise
    def autorefresh?
      @autorefresh
    end

    # Return addons in the repository
    #
    # @return [Array<Packages::RepositoryProduct>] Addons in the repository
    #
    # @see #products
    def addons
      products.select { |p| p.category == :addon }
    end

    # Enable the repository
    #
    # @see Yast::Pkg.SourceSetEnabled
    def enable!
      Yast::Pkg.SourceSetEnabled(repo_id, true)
    end

    # Disable the repository
    #
    # @see Yast::Pkg.SourceSetEnabled
    def disable!
      Yast::Pkg.SourceSetEnabled(repo_id, false)
    end
  end
end
