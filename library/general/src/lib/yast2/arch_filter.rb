# Copyright (c) [2022] SUSE LLC
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

require "yast"

Yast.import "Arch"

module Yast2
  # Represents filtering based on hardware architecture like x86_64 or ppc64.
  # Original code lived in Y2Storage::SubvolSpecification
  # @example
  #   Yast2::ArchFilter.from_string("x86_64,aarch64").match?
  class ArchFilter
    # Error when invalid specification for filter is used
    class Invalid < RuntimeError
      def initialize(spec)
        super("Invalid part of architecture specification '#{spec}'")
      end
    end

    # @return [Array<Hash>] list of specifications where each entry is hash with key `:method` and
    #   `:negate`, where method is Yast::Arch method and negate specify if
    #   method have to return false. There is one specific method `:all` that is not in Yast::Arch,
    #   but can be used to always return true.
    attr_reader :specifications

    # creates new architecture filter from passed list of individual specifications
    # @param specs [Array<String>]
    # @raise Invalid when architecture specification is invalid
    def initialize(specs)
      @specifications = []
      specs.each do |spec|
        method = spec.downcase
        negate = spec.start_with?("!")
        method = spec[1..-1] if negate
        raise Invalid, spec unless valid_method?(method)

        @specifications << { method: method.to_sym, negate: negate }
      end
    end

    # parses architecture filter specification from string.
    # supported values are methods from Yast::Arch with possible `!` in front of it.
    # When "!" is used it is called negative method and without it is called positive.
    # List of possible values are supported with comma separator. In list
    # at least one positive specified method have to return true and all methods
    # with `!` have to be false to return true as result. Whitespaces are allowed. Only `!` and method
    # has to be without space. Also it is case insensitive, so acronyms can be in upper case.
    # @example various format and how it behave in given situations
    #   "x86_64,ppc64" # returns true on either x86_64 or ppc64
    #   "ppc,!board_powernv" # returns false on powernv_board or non-ppc
    #   "ppc, !board_powernv" # spaces are allowed
    #   "!ppc64,!aarch64" # always returns false as there is none positive method
    #   "s390, !is_zKVM" # return true on s390 when not running in zKVM hypervisor
    #   "all,!s390" # return true on all archs except s390
    #   "invalid" # raises ArchFilter::Invalid exception
    def self.from_string(value)
      new(value.split(",").map(&:strip))
    end

    # checks if filter match current hardware
    # @return [Boolean]
    def match?
      negative, positive = @specifications.partition { |s| s[:negate] }
      return false if negative.any? { |s| invoke_method(s[:method]) }

      positive.any? { |s| invoke_method(s[:method]) }
    end

  private

    def invoke_method(name)
      return true if name == :all

      Yast::Arch.public_send(name)
    end

    def valid_method?(name)
      return true if name.to_s == "all"

      Yast::Arch.respond_to?(name)
    end
  end
end
