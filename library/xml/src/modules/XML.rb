# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
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
# File:  modules/XML.ycp
# Package:  XML
# Summary:  XML routines
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class XMLClass < Module
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

    # Read XML file into YCP
    # @param [String] xml_file XML file name to read
    # @return Map with YCP data
    def XMLToYCPFile(xml_file)
      if Ops.greater_than(SCR.Read(path(".target.size"), xml_file), 0)
        Builtins.y2milestone("Reading %1", xml_file)
        out = Convert.convert(
          SCR.Read(path(".xml"), xml_file),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2debug("XML Agent output: %1", out)
        deep_copy(out)
      else
        Builtins.y2warning(
          "XML file %1 (%2) not found",
          xml_file,
          SCR.Read(path(".target.size"), xml_file)
        )
        {}
      end
    end

    # Read XML string into YCP
    # @param xml_string string to read
    # @return Map with YCP data
    def XMLToYCPString(xml_string)
      if Ops.greater_than(Builtins.size(xml_string), 0)
        out = Convert.convert(
          SCR.Read(path(".xml.string"), xml_string),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2debug("XML Agent output: %1", out)
        deep_copy(out)
      else
        Builtins.y2warning("can't convert empty XML string")
        {}
      end
    end

    # The error string from the xml parser.
    # It should be used when the agent did not return content.
    # A reset happens before a new XML parsing starts.
    # @return parser error
    def XMLError
      Convert.to_string(SCR.Read(path(".xml.error_message")))
    end

    publish variable: :cdataSections, type: "list"
    publish variable: :listEntries, type: "map"
    publish variable: :systemID, type: "string"
    publish variable: :rootElement, type: "string"
    publish variable: :nameSpace, type: "string"
    publish variable: :typeNamespace, type: "string"
    publish variable: :docs, type: "map"
    publish function: :xmlCreateDoc, type: "void (symbol, map)"
    publish function: :YCPToXMLFile, type: "boolean (symbol, map, string)"
    publish function: :YCPToXMLString, type: "string (symbol, map)"
    publish function: :XMLToYCPFile, type: "map <string, any> (string)"
    publish function: :XMLToYCPString, type: "map <string, any> (string)"
    publish function: :XMLError, type: "string ()"
  end

  XML = XMLClass.new
  XML.main
end
