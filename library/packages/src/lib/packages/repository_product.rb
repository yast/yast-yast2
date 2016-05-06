module Packages
  class RepositoryProduct
    attr_reader :name, :version, :arch, :status, :category

    def initialize(name:, version:, arch:, status:, category:)
      @arch = arch.to_sym
      @name = name
      @status = status.to_sym
      @category = category.to_sym
      @version = version
    end

    def ==(other)
      arch == other.arch && name == other.name && version == other.version
    end
  end
end
