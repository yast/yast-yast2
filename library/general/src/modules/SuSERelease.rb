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
# Module:	SuSERelease.ycp
#
# Authors:	Jiri Srain <jsrain@suse.de>
#
# Purpose:	Responsible for getting information from the /etc/SuSE-release
#              (and similar for other system) file
#
# $Id$
require "yast"

module Yast
  class SuSEReleaseClass < Module
    def main

      textdomain "base"

      Yast.import "Stage"
    end

    # Make a nice name for a system out of the long name
    # @param [String] longname string the long product name
    # @return [String] nice product name (to be displayed)
    def MakeNiceName(longname)
      p1 = Builtins.find(longname, "(")
      return longname if p1 == -1
      while Ops.greater_than(p1, 1) &&
          Builtins.substring(longname, Ops.subtract(p1, 1), 1) == " "
        p1 = Ops.subtract(p1, 1)
      end
      Builtins.substring(longname, 0, p1)
    end

    # Find and get the contents of the release file
    # @param [String] directory containing the installed system (/ in installed system)
    # @return [String] contents of the release file
    def ReleaseFileContents(directory)
      ret = "?"
      Builtins.foreach(
        ["/etc/SuSE-release", "/etc/UnitedLinux-release", "/etc/redhat-release"]
      ) do |filename|
        contents = Convert.to_string(
          SCR.Read(path(".target.string"), [Ops.add(directory, filename), "?"])
        )
        if contents != "?"
          Builtins.y2milestone("File with release information: %1", filename)
          ret = contents
          raise Break
        end
      end
      ret
    end

    # Get information about the release for displaying in the selection list
    #  of found systems
    # @param [String] directory containing the installed system (/ in installed system)
    # @return [String] the release information
    def ReleaseInformation(directory)
      contents = ReleaseFileContents(directory)
      if contents != nil && contents != "?"
        lines = Builtins.splitstring(contents, "\n")
        return MakeNiceName(Ops.get_string(lines, 0, "?"))
      else
        return "?"
      end
    end

    # Get information about the release for using in the help text
    # Is limited for the currently running product
    # @param directory containing the installed system (/ in installed system)
    # @return [String] the release information
    def ReleaseName
      if Stage.initial
        return Convert.to_string(SCR.Read(path(".content.PRODUCT")))
      end
      contents = ReleaseFileContents("/")
      if contents != "?"
        lines = Builtins.splitstring(contents, "\n")
        lines = Builtins.filter(lines) { |l| l != "" }
        components = Builtins.splitstring(Ops.get(lines, 0, ""), " ")
        after_version = false
        components = Builtins.maplist(components) do |c|
          after_version = true if Builtins.regexpmatch(c, "^[0-9\\.]+$")
          c = nil if after_version
          c
        end
        components = Builtins.filter(components) { |c| c != nil }
        return Builtins.mergestring(components, " ")
      else
        return "SUSE LINUX"
      end
    end

    # Get information about the release
    # Is limited for the currently running product
    # @param directory containing the installed system (/ in installed system)
    # @return [String] the release information
    def ReleaseVersion
      if Stage.initial
        return Convert.to_string(SCR.Read(path(".content.VERSION")))
      end

      contents = ReleaseFileContents("/")
      version = ""

      if contents != "?"
        lines = Builtins.splitstring(contents, "\n")
        lines = Builtins.filter(lines) { |l| l != "" }

        components = Builtins.splitstring(Ops.get(lines, 0, ""), " ")

        Builtins.foreach(components) do |c|
          version = c if version == "" && Builtins.regexpmatch(c, "^[0-9\\.]+$")
        end
      end

      version
    end

    publish :function => :ReleaseInformation, :type => "string (string)"
    publish :function => :ReleaseName, :type => "string ()"
    publish :function => :ReleaseVersion, :type => "string ()"
  end

  SuSERelease = SuSEReleaseClass.new
  SuSERelease.main
end
