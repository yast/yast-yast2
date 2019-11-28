# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LINUX GmbH, Nuremberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"

Yast.import "Pkg"

module Y2Packager
  #
  # This class represents a libzypp resolvable object (package, pattern, patch,
  # product, source package)
  #
  # @note The returned Resolvables might not be valid anymore after changing
  #   the package manager status (installing/removing packages, changing
  #   repositories, etc.). After such a change you need to load the resolvables
  #   again, avoid storing them for later if possible.
  #
  # @example All installed packages
  #   Y2Packager::Resolvable.find(kind: :package, status: :installed)
  #
  # @example Available (not installed) "yast2" packages
  #   Y2Packager::Resolvable.find(kind: :package, status: :available, name: "yast2")
  #
  # @example Lazy loading
  #   res = Y2Packager::Resolvable.find(kind: :package, status: :installed)
  #   # the `summary` attribute is loaded from libzypp when needed
  #   res.each {|r| puts "#{r.name} - {r.summary}"}
  #
  # @example Preloading the attributes
  #   # the `summary` attribute is loaded from libzypp already at the initial state
  #   res = Y2Packager::Resolvable.find(kind: :package, status: :installed, [:summary])
  #   # this returns the cached `summary` attribute, this is much more efficient
  #   res.each {|r| puts "#{r.name} - {r.summary}"}
  #
  # @since 4.2.6
  class Resolvable
    include Yast::Logger

    #
    # Find the resolvables which match the input parameters. See Yast::Pkg.Resolvables
    #
    # @param params [Hash<Symbol,Object>] The search filter, only the matching resolvables
    #    are returned.
    # @param preload [Array<Symbol>] The list of attributes which should be preloaded.
    #    The missing attributes are lazy loaded, however for performance reasons
    #    you might ask to preload the attributes right at the beginning and avoid
    #    querying libzypp again later.
    # @return [Array<Y2Packager::Resolvable>] Found resolvables or empty array if nothing found
    # @see https://yast-pkg-bindings.surge.sh/ Yast::Pkg.Resolvables
    def self.find(params, preload = [])
      attrs = (preload + UNIQUE_ATTRIBUTES).uniq
      Yast::Pkg.Resolvables(params, attrs).map { |r| new(r) }
    end

    #
    # Is there any resolvable matching the requested parameters? This is similar to
    # the .find method, just instead of a resolvable list it returns a simple Boolean.
    #
    # @param params [Hash<Symbol,Object>] The requested attributes
    # @return [Boolean] `true` if any matching resolvable is found, `false` otherwise.
    # @see .find
    def self.any?(params)
      Yast::Pkg.AnyResolvable(params)
    end

    #
    # Constructor, initialize the object from a pkg-bindings resolvable hash.
    #
    # @param hash [Hash<Symbol,Object>] A pkg-bindings resolvable hash.
    def initialize(hash)
      from_hash(hash)
    end

    #
    # Dynamically load the missing attributes from libzypp.
    #
    # @param method [Symbol] the method called
    # @param args not used so far, raises ArgumentError if anything is passed
    #
    # @return the loaded value from libzypp
    #
    def method_missing(method, *args)
      if instance_variable_defined?("@#{method}")
        raise ArgumentError, "Method #{method} does not accept arguments" unless args.empty?

        return instance_variable_get("@#{method}")
      end

      # load a missing attribute
      if !UNIQUE_ATTRIBUTES.all? { |a| instance_variable_defined?("@#{a}") }
        raise "Missing attributes for identifying the resolvable."
      end

      load_attribute(method)
      super unless instance_variable_defined?("@#{method}")
      raise ArgumentError, "Method #{method} does not accept arguments" unless args.empty?

      instance_variable_get("@#{method}")
    end

    # defines for dynamic methods also respond_to?
    def respond_to_missing?(method, _private)
      return true if instance_variable_defined?("@#{method}")
      return true if UNIQUE_ATTRIBUTES.include?(method.to_sym)

      false
    end

  private

    # attributes required for identifying a resolvable
    UNIQUE_ATTRIBUTES = [:kind, :name, :version, :arch, :source].freeze

    # Load the attributes from a Hash
    #
    # @param hash [Hash] The resolvable Hash obtained from pkg-bindings.
    def from_hash(hash)
      hash.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end

    #
    # Lazy load a missing attribute.
    #
    # @param attr [Symbol] The required attribute to load.
    # @return [Object] The read value.
    def load_attribute(attr)
      attrs = Hash[(UNIQUE_ATTRIBUTES.map { |a| [a, instance_variable_get("@#{a}")] })]
      resolvables = Yast::Pkg.Resolvables(attrs, [attr])

      # Finding more than one result is suspicious, log a warning
      log.warn("Found several resolvables: #{resolvables.inspect}") if resolvables.size > 1

      resolvable = resolvables.first
      return unless resolvable&.key?(attr.to_s)

      instance_variable_set("@#{attr}", resolvable[attr.to_s])
    end
  end
end
