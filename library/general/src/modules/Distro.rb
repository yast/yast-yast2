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
# File:	modules/Distro.ycp
# Module:	yast2
# Summary:	Distinguish between distributions that can run YaST
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
require "yast"

module Yast
  class DistroClass < Module
    def main
      textdomain "base"

      # Cache
      @_distro = nil
    end

    # Is it SUSE based? openSUSE, SLES, SLED, ...
    def suse
      if @_distro.nil?
        if SCR.Read(path(".target.size"), "/etc/SuSE-release") != -1
          @_distro = "suse"
          Builtins.y2milestone("Found SUSE")
        end
      end

      @_distro == "suse"
    end

    # Is it Fedora based? RHEL, Oracle, ...
    def fedora
      if @_distro.nil?
        if SCR.Read(path(".target.size"), "/etc/fedora-release") != -1
          @_distro = "fedora"
          Builtins.y2milestone("Found Fedora")
        end
      end

      @_distro == "fedora"
    end

    # Is it Debian based? Ubuntu, ...
    def debian
      if @_distro.nil?
        if SCR.Execute(
          path(".target.bash"),
          "grep DISTRIB_ID=Ubuntu /etc/lsb-release"
        ) == 0
          @_distro = "debian"
          Builtins.y2milestone("Found Debian/Ubuntu")
        end
      end

      @_distro == "debian"
    end

    publish function: :suse, type: "boolean ()"
    publish function: :fedora, type: "boolean ()"
    publish function: :debian, type: "boolean ()"
  end

  Distro = DistroClass.new
  Distro.main
end
