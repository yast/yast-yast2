module Packages
  # NOTE: Please, DO NOT USE THIS CLASS but Y2Packager::Product. This class is
  # here only to retain compatibility with yast2-packager 3.3.2 which is the
  # version on Factory until storage-ng is completely merged.
  #
  # Represent a product which is present in a repository. At this
  # time this class is responsible for finding out whether two
  # products instances are the same (for example, coming from different
  # repositories).
  class Product
    include Yast::Logger

    # @return [String] Name
    attr_reader :name
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

    # Constructor
    #
    # @param name     [String] Name
    # @param version  [String] Version
    # @param arch     [String] Architecture
    # @param status   [Symbol] Status (:selected, :removed, :installed, :available)
    # @param category [Symbol] Category (:base, :addon)
    # @param vendor   [String] Vendor
    def initialize(name:, version:, arch:, status:, category:, vendor:)
      @name = name
      @version = version
      @arch = arch.to_sym
      @status = status.to_sym
      @category = category.to_sym
      @vendor = vendor
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
  end
end
