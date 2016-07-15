# encoding: utf-8

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
# File:	modules/XML.ycp
# Package:	XML
# Summary:	XML routines
# Authors:	Anas Nashif <nashif@suse.de>
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
    def xmlCreateDoc(doc, docSettings)
      docSettings = deep_copy(docSettings)
      current_settings = {
        "cdataSections" => Ops.get_list(
          docSettings,
          "cdataSections",
          @cdataSections
        ),
        "systemID"      => Ops.get_string(docSettings, "systemID", @systemID),
        "rootElement"   => Ops.get_string(
          docSettings,
          "rootElement",
          @rootElement
        ),
        "listEntries"   => Ops.get_map(docSettings, "listEntries", @listEntries)
      }
      if Ops.get_string(docSettings, "typeNamespace", "") != ""
        Ops.set(
          current_settings,
          "typeNamespace",
          Ops.get_string(docSettings, "typeNamespace", "")
        )
      end

      if Ops.get_string(docSettings, "nameSpace", "") != ""
        Ops.set(
          current_settings,
          "nameSpace",
          Ops.get_string(docSettings, "nameSpace", "")
        )
      end
      Ops.set(@docs, doc, current_settings)
      nil
    end

    # YCPToXMLFile()
    # Write YCP data into formated XML file
    # @param symbol Document type identifier
    # @param [Hash] contents  a map with YCP data
    # @param [String] outputPath the path of the XML file
    # @return [Boolean] true on sucess
    def YCPToXMLFile(docType, contents, outputPath)
      contents = deep_copy(contents)
      if !Builtins.haskey(@docs, docType)
        Builtins.y2error("doc type %1 undecalred...", docType)
        return false
      end
      docSettings = Ops.get_map(@docs, docType, {})
      Ops.set(docSettings, "fileName", outputPath)
      Builtins.y2debug("Write(.xml, %1, %2)", docSettings, contents)
      ret = Convert.to_boolean(SCR.Execute(path(".xml"), docSettings, contents))
      ret
    end

    # Write YCP data into formated XML string
    #  @param symbol Document type identifier
    #  @param [Hash] contents  a map with YCP data
    #  @return [String] String with XML data
    def YCPToXMLString(docType, contents)
      contents = deep_copy(contents)
      return nil if !Builtins.haskey(@docs, docType)

      docSettings = Ops.get_map(@docs, docType, {})
      Ops.set(docSettings, "fileName", "dummy")
      ret = SCR.Execute(path(".xml.string"), docSettings, contents)

      Ops.is_string?(ret) ? Convert.to_string(ret) : ""
    end

    # Read XML file into YCP
    # @param [String] xmlFile XML file name to read
    # @return Map with YCP data
    def XMLToYCPFile(xmlFile)
      if Ops.greater_than(SCR.Read(path(".target.size"), xmlFile), 0)
        Builtins.y2milestone("Reading %1", xmlFile)
        out = Convert.convert(
          SCR.Read(path(".xml"), xmlFile),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2debug("XML Agent output: %1", out)
        return deep_copy(out)
      else
        Builtins.y2warning(
          "XML file %1 (%2) not found",
          xmlFile,
          SCR.Read(path(".target.size"), xmlFile)
        )
        return {}
      end
    end

    # Read XML string into YCP
    # @param XML string to read
    # @return Map with YCP data
    def XMLToYCPString(xmlString)
      if Ops.greater_than(Builtins.size(xmlString), 0)
        out = Convert.convert(
          SCR.Read(path(".xml.string"), xmlString),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2debug("XML Agent output: %1", out)
        return deep_copy(out)
      else
        Builtins.y2warning("can't convert empty XML string")
        return {}
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
