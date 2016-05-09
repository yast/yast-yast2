module Packages
  class RepositoryProduct
    attr_reader :name, :version, :arch, :status, :category, :vendor

    def initialize(name:, version:, arch:, status:, category:, vendor:)
      @arch = arch.to_sym
      @name = name
      @status = status.to_sym
      @category = category.to_sym
      @version = version
      @vendor = vendor
    end

    def ==(other)
      arch == other.arch && name == other.name &&
        version == other.version && vendor == other.vendor
    end
  end
end
