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
# File:	modules/XVersion.ycp
# Module:	yast2
# Summary:	Differences between multiple X versions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
require "yast"

module Yast
  class XVersionClass < Module
    def main
      # All paths related to X server
      @_paths = nil
    end

    # Initialize the paths
    def Initialize
      keys = SCR.Dir(path(".x_version"))
      if Ops.greater_than(Builtins.size(keys), 0)
        @_paths = {}
        Builtins.foreach(keys) do |k|
          id = Builtins.substring(k, 1)
          Ops.set(
            @_paths,
            id,
            Convert.to_string(SCR.Read(Builtins.add(path(".x_version"), k)))
          )
        end
        Builtins.y2milestone("X11 paths: %1", @_paths)
      else
        Builtins.y2error("Data for XVersion not defined!")
      end

      nil
    end

    # Provide a path
    # @param [String] id string path identification to provide
    # @return [String] required path, nil if not defined
    def Path(id)
      Initialize() if @_paths.nil?
      Ops.get(@_paths, id)
    end

    # wrappers below

    # Provide path to bin directory of X11
    # @return [String] path to /usr/X11R6/bin, resp. /usr/bin
    def binPath
      Path("bindir")
    end

    # Provide path to lib directory of X11
    # @return [String] path to /usr/X11R6/lib, resp. /usr/lib
    def libPath
      Path("libdir")
    end

    # Provide path to lib64 directory of X11
    # @return [String] path to /usr/X11R6/lib64, resp. /usr/lib64
    def lib64Path
      Path("lib64dir")
    end

    # Provide path to man directory of X11
    # @return [String] path to /usr/X11R6/man, resp. /usr/man
    def manPath
      Path("mandir")
    end

    # Provide path to include directory of X11
    # @return [String] path to /usr/X11R6/include, resp. /usr/include
    def includePath
      Path("includedir")
    end

    # Provide path to share directory of X11
    # @return [String] path to /usr/X11R6/share, resp. /usr/share
    def sharePath
      Path("sharedir")
    end

    # Provide path to info directory of X11
    # @return [String] path to /usr/X11R6/info, resp. /usr/info
    def infoPath
      Path("infodir")
    end

    # Provide path to font directory of X11
    # @return [String] path to /usr/X11R6/font, resp. /usr/font
    def fontPath
      Path("fontdir")
    end

    publish function: :Path, type: "string (string)"
    publish function: :binPath, type: "string ()"
    publish function: :libPath, type: "string ()"
    publish function: :lib64Path, type: "string ()"
    publish function: :manPath, type: "string ()"
    publish function: :includePath, type: "string ()"
    publish function: :sharePath, type: "string ()"
    publish function: :infoPath, type: "string ()"
    publish function: :fontPath, type: "string ()"
  end

  XVersion = XVersionClass.new
  XVersion.main
end
