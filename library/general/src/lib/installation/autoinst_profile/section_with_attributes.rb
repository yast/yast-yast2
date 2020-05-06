# Copyright (c) [2017] SUSE LLC
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

module Installation
  module AutoinstProfile
    # Abstract base class for some AutoYaST profile sections
    class SectionWithAttributes
      include Yast::Logger

      class << self
        # Description of the attributes in the section.
        #
        # To be defined by each subclass. Each entry contains a hash with the
        # mandatory key :name and an optional key :xml_name.
        #
        # @return [Array<Hash>]
        def attributes
          []
        end

        # Creates an instance based on the profile representation used by the
        # AutoYaST modules (nested arrays and hashes).
        #
        # This method provides no extra validation, type conversion or
        # initialization to default values. Those responsibilities belong to the
        # AutoYaST modules. The hash is expected to be valid and
        # contain the relevant information. Attributes are set to nil for
        # missing keys and for blank values.
        #
        # @param hash   [Hash] content of the corresponding section of the profile.
        #   Each element of the hash corresponds to one of the attributes
        #   defined in the section.
        # @param parent [#parent,#section_name] parent section
        # @return [SectionWithAttributes]
        def new_from_hashes(hash, parent = nil)
          result = new(parent)
          result.init_from_hashes(hash)
          result
        end

      protected

        # Macro used in the subclasses to define accessors for all the
        # attributes defined by {.attributes}
        def define_attr_accessors
          attributes.each do |attrib|
            attr_accessor attrib[:name]
          end
        end
      end

      # This value only makes sense when {.new_from_hashes} is used.
      #
      # @return [#parent,#section_name] Parent section
      attr_reader :parent

      # Constructor
      #
      # @param parent [SectionWithAttributes] Parent section
      def initialize(parent = nil)
        @parent = parent
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # By default, it simply assigns the non-empty hash values to the
      # corresponding attributes, logging unknown keys. The subclass is expected
      # to refine this behavior if needed.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        init_scalars_from_hash(hash)
      end

      # Content of the section in the format used by the AutoYaST modules
      # (nested arrays and hashes).
      #
      # @return [Hash] each element of the hash corresponds to one of the
      #     attributes defined in the section. Blank attributes are not
      #     included.
      def to_hashes
        attributes.each_with_object({}) do |attrib, result|
          value = attrib_value(attrib)
          next if attrib_skip?(value)

          key = attrib_key(attrib)
          result[key] = value
        end
      end

      # Returns the section name
      #
      # In some cases, the section name does not match with the XML name
      # and this method should be redefined.
      #
      # @example
      #   section = PartitioningSection.new
      #   section.section_name #=> "partitioning"
      #
      # @return [String] Section name
      def section_name
        klass_name = self.class.name.split("::").last
        klass_name
          .gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase
          .chomp("_section")
      end

    protected

      def attributes
        self.class.attributes
      end

      # Whether an attribute must be skipped during import/export.
      #
      # @return [Boolean] true is the value is blank
      def attrib_skip?(value)
        value.nil? || value == [] || value == ""
      end

      def attrib_key(attrib)
        (attrib[:xml_name] || attrib[:name]).to_s
      end

      def attrib_value(attrib)
        value = send(attrib[:name])
        if value.is_a?(Array)
          value.map { |v| attrib_scalar(v) }
        else
          attrib_scalar(value)
        end
      end

      def attrib_scalar(element)
        element.respond_to?(:to_hashes) ? element.to_hashes : element
      end

      def attrib_name(key)
        attrib = attributes.detect { |a| a[:xml_name] == key.to_sym || a[:name] == key.to_sym }
        return nil unless attrib

        attrib[:name]
      end

      def init_scalars_from_hash(hash)
        hash.each_pair do |key, value|
          name = attrib_name(key)

          if name.nil?
            log.warn "Attribute #{key} not recognized by #{self.class}. Check the XML schema."
            next
          end

          # This method only reads scalar values
          next if value.is_a?(Array) || value.is_a?(Hash)

          if attrib_skip?(value)
            log.debug "Ignored blank value (#{value}) for #{key}"
            next
          end

          send(:"#{name}=", value)
        end
      end
    end
  end
end
