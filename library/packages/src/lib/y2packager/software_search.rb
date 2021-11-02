# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

module Y2Packager
  # Query the software manager for resolvables (packages, products, applications,
  # and so on).
  #
  # Should we have two different classes? One for the conditions/properties
  # and the other one that represents the query itself. See Backend#search for
  # an explanation.
  #
  # The SoftwareSearch contains additional information, like the list of backends.
  #
  # @example Search by name
  #   query = SoftwareSearch.new(backend)
  #
  class SoftwareSearch
    include Enumerable

    # @return [Array<Backend>] Limit the search to these backends
    attr_reader :backends

    # @return [Array<Symbol>] Properties to include
    attr_reader :properties

    # @return [Hash<Symbol,String>] A hash describing the conditions (e.g., {
    #   name: "yast2" })
    attr_reader :conditions

    # attributes required for identifying a resolvable
    BASE_ATTRIBUTES = [:kind, :name, :version, :arch, :source].freeze

    def initialize(*backends)
      @backends = backends # limit the query to these backends
      @properties = BASE_ATTRIBUTES.dup
      @conditions = {}
    end

    def named(name)
      with(name: name)
      self
    end

    def including(*names)
      @properties.concat(names)
      self
    end

    def excluding(*names)
      names.each { |a| @properties.delete(a) }
      self
    end

    def with(conds = {})
      @conditions.merge!(conds)
      self
    end

    # @todo Rely on a ResolvablesCollection instead
    def each(&block)
      resolvables.each(&block)
    end

  private

    def resolvables
      backends.each_with_object([]) do |backend, all|
        all.concat(backend.search(conditions: conditions, properties: properties))
      end
    end
  end
end
