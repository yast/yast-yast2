# Copyright (c) [2020] SUSE LLC
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

module Installation
  module AutoinstProfile
    # This class represents an element path in a profile
    #
    # @example Create a new path
    #   ProfilePath.
    class ElementPath
      extend Forwardable

      def_delegators :@parts, :first, :last

      class << self
        # Returns a ProfilePath from a string
        #
        # It uses {from_generic_path} or {from_simple_path} as needed.
        #
        # @param str [String] String to parse
        # @return [ProfilePath] Profile path
        def from_string(str)
          str.start_with?("//") ? from_simple_xpath(str) : from_generic_path(str)
        end

        # Returns a ProfilePath from an ask-list path style
        #
        # @example Path to the username of the first user
        #   ProfilePath.from_generic_path("users,0,username")
        #
        # @param str [String] Path string
        # @return [ProfilePath] Profile path
        def from_generic_path(str)
          parts = str.split(",").each_with_object([]) do |part, all|
            element = (part =~ /\A\d+\Z/) ? part.to_i : part
            all.push(element)
          end
          new(*parts)
        end

        SIMPLE_XPATH_FRAGMENT = /(\w+)\[(\d+)\]/.freeze
        private_constant :SIMPLE_XPATH_FRAGMENT

        # Returns a ProfilePath from an ask-list path style
        #
        # @example Path to the username of the first user
        #   ProfilePath.from_simple_xpath("//users[0]/username")
        #
        # @param str [String] Path string
        # @return [ProfilePath] Profile path
        def from_simple_xpath(str)
          xpath = str.delete_prefix("//")
          parts = xpath.split("/").each_with_object([]) do |part, path|
            match = SIMPLE_XPATH_FRAGMENT.match(part)
            if match
              path.push(match[1], match[2].to_i)
            else
              path.push(part)
            end
          end
          new(*parts)
        end
      end

      # Constructor
      #
      # @param parts [Array<String>] Profile path parts
      def initialize(*parts)
        @parts = parts
      end

      # Returns the path parts
      #
      # @return [Array<String>] An array containing the path parts
      def to_a
        @parts
      end

      # Returns a new path composed by the given parts
      #
      # @example Extend a path with an string
      #   path = ProfilePath.new("general")
      #   path.join("mode") #=> ProfilePath.new("general", "mode")
      #
      # @example Combine ProfilePath and strings
      #   path = ProfilePath.new("general")
      #   suffix = ProfilePath.new("mode")
      #   path.join(suffix, "confirm") #=> ProfilePath.new("general", "mode", "confirm")
      #
      # @param parts_or_path [Array<String,ProfilePath>] Parts or paths to join
      # @return [ProfilePath] New profile path
      def join(*parts_or_path)
        new_parts = parts_or_path.reduce([]) do |all, element|
          new_elements = element.respond_to?(:to_a) ? element.to_a : [element]
          all + new_elements
        end

        self.class.new(*(@parts + new_parts))
      end

      # Compares two paths
      #
      # Two paths are considered to be equivalent if they have the same parts.
      #
      # @param other [ProfilePath] Profile path to compare with
      # @return [Boolean] true if they are equal; false otherwise
      def ==(other)
        @parts == other.to_a
      end

      def to_simple_xpath
        xpath = @parts.each_with_object("") do |e, str|
          fragment = e.is_a?(::String) ? "/#{e}" : "[#{e}]"
          str << fragment
        end

        "/#{xpath}"
      end

      def to_generic_path
        @parts.join(",")
      end
    end
  end
end
