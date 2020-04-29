# ***************************************************************************
#
# Copyright (c) 2002 - 2020 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************

require "yast"

require "nokogiri"

module Yast
  # Exception used when serializing ruby object that contain invalid object like nil,
  # not supported object or non string hash key.
  class XMLInvalidObject < RuntimeError
  end

  # Specialed exception used when serializing ruby object that contain nil.
  class XMLNilObject < XMLInvalidObject
    attr_reader :object

    def initialize(object)
      @object = object
      super("Nil passed to XML serializer in #{object.inspect}.")
    end
  end

  # Specialed exception used when serializing ruby hash that that contain non string key.
  class XMLInvalidKey < XMLInvalidObject
    attr_reader :key

    def initialize(key)
      @key = key
      super("Non string key '#{key.inspect}' passed to XML serializer.")
    end
  end

  # Exception used when parsing xml string either syntax error or invalid values in element.
  class XMLInvalidContent < RuntimeError
  end

  # Specialized exception used when syntax error in XML is found
  class XMLParseError < XMLInvalidContent
    def initialize(error)
      super(error)
    end
  end

  class XMLClass < Module
    include Yast::Logger

    def main
      # Sections in XML file that should be treated as CDATA when saving
      @cdataSections = []

      # How to call a list entry in the XML output
      @listEntries = {}

      # The system ID, or the DTD URI
      @systemID = ""

      # root element of the XML file
      @rootElement = ""

      # Global Namespace xmlns=...
      @nameSpace = "http://www.suse.com/1.0/yast2ns"

      # Type name space xmlns:config for YCP data (http://www.suse.com/1.0/configns)
      @typeNamespace = "http://www.suse.com/1.0/configns"

      @docs = {}
    end

    # define a new doc type with custom settings, if not defined, global settings will
    # be used.
    # @param symbol Document type identifier
    # @param map  Document type Settings
    # @return [void]
    def xmlCreateDoc(doc, doc_settings)
      doc_settings = deep_copy(doc_settings)
      current_settings = {
        "cdataSections" => Ops.get_list(
          doc_settings,
          "cdataSections",
          @cdataSections
        ),
        "systemID"      => Ops.get_string(doc_settings, "systemID", @systemID),
        "rootElement"   => Ops.get_string(
          doc_settings,
          "rootElement",
          @rootElement
        ),
        "listEntries"   => Ops.get_map(doc_settings, "listEntries", @listEntries)
      }
      if Ops.get_string(doc_settings, "typeNamespace", "") != ""
        Ops.set(
          current_settings,
          "typeNamespace",
          Ops.get_string(doc_settings, "typeNamespace", "")
        )
      end

      if Ops.get_string(doc_settings, "nameSpace", "") != ""
        Ops.set(
          current_settings,
          "nameSpace",
          Ops.get_string(doc_settings, "nameSpace", "")
        )
      end
      Ops.set(@docs, doc, current_settings)
      nil
    end

    # YCPToXMLFile()
    # Write YCP data into formated XML file
    # @param [Symbol] doc_type Document type identifier
    # @param [Hash] contents  a map with YCP data
    # @param [String] output_path the path of the XML file
    # @return [Boolean] true on sucess
    # @raise [XMLInvalidObject] when non supported contents is passed
    def YCPToXMLFile(doc_type, contents, output_path)
      xml = YCPToXMLString(doc_type, contents)
      return false unless xml

      SCR.Write(path(".target.string"), output_path, xml)
    end

    # Write YCP data into formated XML string
    # @param [Symbol] doc_type Document type identifier
    # @param [Hash] contents  a map with YCP data
    # @return [String, nil] String with XML data or nil if error happen
    # @raise [XMLInvalidObject] when non supported contents is passed
    def YCPToXMLString(doc_type, contents)
      contents = deep_copy(contents)
      metadata = @docs[doc_type]
      if !metadata
        log.error "Calling YCPToXML with unknown doc_type #{doc_type.inspect}. " \
          "Known types #{@docs.keys.inspect}"
        return nil
      end

      doc = Nokogiri::XML::Document.new("1.0")
      root_name = metadata["rootElement"]
      if !root_name || root_name.empty?
        log.warn "root element missing in docs #{metadata.inspect}"
        return nil
      end

      doc.create_internal_subset(root_name, nil, metadata["systemID"])

      root = doc.create_element root_name
      root.default_namespace = metadata["nameSpace"] if metadata["nameSpace"]
      root.add_namespace("config", metadata["typeNamespace"]) if metadata["typeNamespace"]

      add_element(doc, metadata, root, contents)

      doc.root = root
      doc.to_xml
    end

    # Reads XML file
    # @param [String] xml_file XML file name to read
    # @return [Hash] parsed content
    # @raise [XMLInvalidContent] when non supported xml is passed
    def XMLToYCPFile(xml_file)
      raise XMLInvalidContent, "Cannot find XML file" if SCR.Read(path(".target.size"), xml_file) <= 0

      log.info "Reading #{xml_file}"
      XMLToYCPString(SCR.Read(path(".target.string"), xml_file))
    end

    # Reads XML string
    # @param [String] xml_string to read
    # @return [Hash] parsed content or nil if error happen and in such case
    #   error reason is in {#XMLError}
    # @raise [XMLInvalidContent] when non supported xml is passed
    def XMLToYCPString(xml_string)
      result = {}
      raise XMLInvalidContent, "Cannot convert empty XML string" if !xml_string || xml_string.empty?

      doc = Nokogiri::XML(xml_string, &:strict)
      doc.remove_namespaces! # remove fancy namespaces to make user life easier
      # inspect only element nodes
      doc.root.children.select(&:element?).each { |n| parse_node(n, result) }

      result
    rescue Nokogiri::XML::SyntaxError => e
      raise XMLParseError, e.message
    end

    # Validates given schema
    #
    # @param xml [String] path or content of XML
    # @param schema [String] path or content of relax ng schema
    # @return [String] string with errors or empty string
    def XMLValidation(xml, schema)
      xml = SCR.Read(path(".target.string"), xml) unless xml.include?("\n")
      if schema.include?("\n") # content, not path
        validator = Nokogiri::XML::RelaxNG(schema)
      else
        schema_content = SCR.Read(path(".target.string"), schema)
        schema_path = File.dirname(schema)
        # change directory so relative include works
        Dir.chdir(schema_path) { validator = Nokogiri::XML::RelaxNG(schema_content) }
      end

      doc = Nokogiri::XML(xml)
      validator.validate(doc).map(&:message).join("\n")
    end

    # The error string from the xml parser.
    # It should be used when the agent did not return content.
    # A reset happens before a new XML parsing starts.
    # @return nil
    # @deprecated Exception is used instead
    def XMLError
      nil
    end

    publish function: :xmlCreateDoc, type: "void (symbol, map)"
    publish function: :YCPToXMLFile, type: "boolean (symbol, map, string)"
    publish function: :YCPToXMLString, type: "string (symbol, map)"
    publish function: :XMLToYCPFile, type: "map <string, any> (string)"
    publish function: :XMLToYCPString, type: "map <string, any> (string)"
    publish function: :XMLError, type: "string ()"

  private

    BOOLEAN_MAP = {
      "true"  => true,
      "false" => false
    }.freeze

    def parse_node(node, result)
      text = node.xpath("text()").text.strip
      # use only element children
      children = node.children
      children = children.select(&:element?)
      # we need just direct text under node. Can be splitted with another elements
      # but remove whitespace only text
      name = node.name
      type = node["type"]
      if !type
        if text.empty? && !children.empty?
          type = "map"
        elsif !text.empty? && children.empty?
          type = "string"
        # keep cdata trick to create empty string
        elsif !node.children.reject(&:text?).select(&:cdata?).empty?
          type = "string"
        elsif text.empty? && children.empty?
          raise XMLInvalidContent, "xml #{node.name} is empty without type specified"
        else
          raise XMLInvalidContent, "xml #{node.name} contain both text #{text} and children #{children.inspect}."
        end
      end

      case type
      when "string" then value = text
      when "symbol"
        raise XMLInvalidContent, "xml node '#{node.name}' is empty. Forbidden for symbol." if text.empty?

        value = text.to_sym
      when "integer"
        raise XMLInvalidContent, "xml node '#{node.name}' is empty. Forbidden for integer." if text.empty?
        raise XMLInvalidContent, "xml node '#{node.name}' is invalid integer." if text !~ /-?\d+/

        value = text.to_i
      when "boolean"
        value = BOOLEAN_MAP[text]
        raise XMLInvalidContent, "xml node '#{node.name}' is invalid. Only true and false is allowed for boolean." if value.nil?
      when "list"
        value = []
        children.each do |kid|
          # always pass new hash to prevent overwrite for list with same elements
          r = {}
          parse_node(kid, r)
          value.concat(r.values)
        end
      when "map"
        value = {}
        children.each do |kid|
          parse_node(kid, value)
        end
      else
        raise XMLInvalidContent, "XML node #{node.name} contain invalid type #{type.inspect}"
      end

      result[name] = value

      result
    end

    # @param [Nokogiri::XML::Document] doc
    # @param [Hash] metadata for current doc
    # @param [Nokogiri::XML::Node] parent
    # @param [Hash] content to write
    # @return [void]
    def add_element(doc, metadata, parent, contents)
      # backward compatibility. Keys are sorted and needs old ycp sort to be able to compare also classes
      Builtins.sort(contents.keys).each do |key|
        raise XMLInvalidKey, key unless key.is_a?(::String)

        value = contents[key]
        type_attr = metadata["typeNamespace"] ? ("config:") : ""
        type_attr << "type"
        element = Nokogiri::XML::Node.new(key, doc)
        case value
        when ::String
          element[type_attr] = "string"
          element.content = value
        when ::Integer
          element[type_attr] = "integer"
          element.content = value.to_s
        when ::Symbol
          element[type_attr] = "symbol"
          element.content = value.to_s
        when true, false
          element[type_attr] = "boolean"
          element.content = value.to_s
        when ::Array
          element[type_attr] = "list"
          special_names = metadata["listEntries"] || {}
          element_name = special_names[key] || "listentry"
          value.each do |list_value|
            add_element(doc, metadata, element, element_name => list_value)
          end
        when ::Hash
          element[type_attr] = "map"
          add_element(doc, metadata, element, value)
        when nil
          raise XMLNilObject, contents
        else
          raise XMLInvalidObject, "Unsupported element #{value.inspect} class #{value.class.inspect}"
        end

        parent << element
      end
    end
  end

  XML = XMLClass.new
  XML.main
end
