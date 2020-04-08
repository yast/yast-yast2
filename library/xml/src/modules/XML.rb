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
    def YCPToXMLFile(doc_type, contents, output_path)
      contents = deep_copy(contents)
      if !Builtins.haskey(@docs, doc_type)
        Builtins.y2error("doc type %1 undeclared...", doc_type)
        return false
      end
      docSettings = Ops.get_map(@docs, doc_type, {})
      Ops.set(docSettings, "fileName", output_path)
      Builtins.y2debug("Write(.xml, %1, %2)", docSettings, contents)
      ret = Convert.to_boolean(SCR.Execute(path(".xml"), docSettings, contents))
      ret
    end

    # Write YCP data into formated XML string
    # @param [Symbol] doc_type Document type identifier
    # @param [Hash] contents  a map with YCP data
    # @return [String] String with XML data
    def YCPToXMLString(doc_type, contents)
      contents = deep_copy(contents)
      return nil if !Builtins.haskey(@docs, doc_type)

      docSettings = Ops.get_map(@docs, doc_type, {})
      Ops.set(docSettings, "fileName", "dummy")
      ret = SCR.Execute(path(".xml.string"), docSettings, contents)

      Ops.is_string?(ret) ? Convert.to_string(ret) : ""
    end

    # Reads XML file
    # @param [String] xml_file XML file name to read
    # @return [Hash] parsed content
    def XMLToYCPFile(xml_file)
      if SCR.Read(path(".target.size"), xml_file) <= 0
        log.warn "XML file #{xml_file} not found"
        return {}
      end

      log.info "Reading #{xml_file}"
      XMLToYCPString(SCR.Read(path(".target.string"), xml_file))
    end

    # Reads XML string
    # @param [String] xml_string to read
    # @return [Hash] parsed content
    def XMLToYCPString(xml_string)
      @xml_error = ""
      result = {}
      if !xml_string || xml_string.empty?
        log.warn "can't convert empty XML string"
        return result
      end

      doc = Nokogiri::XML(xml_string) { |config| config.strict }
      doc.remove_namespaces! # remove fancy namespaces to make user life easier
      doc.root.children.each { |n| parse_node(n, result) }

      result
    rescue Nokogiri::XML::SyntaxError => e
      @xml_error = e.message

      return nil
    end

    # The error string from the xml parser.
    # It should be used when the agent did not return content.
    # A reset happens before a new XML parsing starts.
    # @return parser error
    def XMLError
      @xml_error
    end

    publish function: :xmlCreateDoc, type: "void (symbol, map)"
    publish function: :YCPToXMLFile, type: "boolean (symbol, map, string)"
    publish function: :YCPToXMLString, type: "string (symbol, map)"
    publish function: :XMLToYCPFile, type: "map <string, any> (string)"
    publish function: :XMLToYCPString, type: "map <string, any> (string)"
    publish function: :XMLError, type: "string ()"

  private

    BOOLEAN_MAP = {
      "true" => true,
      "false" => false
    }

    def parse_node(node, result)
      children = node.children
      # we need just direct text under node. Can be splitted with another elements
      # but remove whitespace only text
      text = node.xpath('text()').text.sub(/\A\s+\z/, "")
      name = node.name
      type = node["type"]
      if !type
        if text.empty? && children.empty? # empty node. Skip element according to backward compatibility
          return result
        elsif text.empty? && !children.empty?
          type = "map"
        elsif !text.empty? && children.empty?
          type = "string"
        else
          log.error "xml #{node.name} contain both text #{text} and children #{children.size}."
          type = "string"
        end
      end

      case type
      when "string" then value = text
      when "symbol" then value = text.to_sym
      when "integer" then value = text.to_i
      when "boolean"
        value = BOOLEAN_MAP[text]
        if value.nil?
          log.warn "invalid value '#{text}' for boolean #{node.name}"
          value = false
        end
      when "list"
        value = []
        children.each do |node|
          # always pass new hash to prevent overwrite for list with same elements
          r = {}
          parse_node(node, r)
          value.concat(r.values)
        end
      when "map"
        value = {}
        children.each do |node|
          parse_node(node, value)
        end
      else
        raise "Unexpected type '#{type.inspect}'"
      end

      result[name] = value

      result
    end
  end

  XML = XMLClass.new
  XML.main
end
