# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2013 Novell, Inc.
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
#
# Purpose:  Responsible for getting information from the /etc/os-release file
#
require "yast"

module Yast

  import "Misc"
  import "Stage"

  class OSReleaseClass < Module
    def initialize
      @file_path        = "/etc/os-release"
    end

    # Get information about the OS release
    # @param [String] directory containing the installed system (/ in installed system)
    # @return [String] the release information
    def ReleaseInformation(directory)
      MakeNiceName(Misc.CustomSysconfigRead("PRETTY_NAME", "?", directory + @file_path))
    end

    # Get information about the OS name
    # Is limited for the currently running product
    # @return [String] the release information
    def ReleaseName
      if Stage.initial
        return SCR.Read(path(".content.PRODUCT"))
      end
      directory = "/" # TODO make this optional argument
      Misc.CustomSysconfigRead("NAME", "SUSE LINUX", directory + @file_path)
    end

    # Get information about the OS version
    # Is limited for the currently running product
    # @return [String] the release information
    def ReleaseVersion
      if Stage.initial
        return SCR.Read(path(".content.VERSION"))
      end
      directory = "/"
      Misc.CustomSysconfigRead("VERSION_ID", "", directory + @file_path)
    end


    publish :function => :ReleaseInformation, :type => "string (string)"
    publish :function => :ReleaseName, :type => "string ()"
    publish :function => :ReleaseVersion, :type => "string ()"

    private

    # Make a nice name for a system out of the long name
    # @param [String] longname string the long product name
    # @return [String] nice product name (to be displayed)
    def MakeNiceName(longname)
      # remove everything after first left parenthesis and spaces leading to it
      longname.gsub(/[ ]*\(.*/, "")
    end
  end

  OSRelease = OSReleaseClass.new
end
