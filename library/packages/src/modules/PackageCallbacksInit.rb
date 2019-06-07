# typed: false
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
# File:	modules/PackageCallbacksInit.ycp
# Package:	yast2
# Summary:	Initialize packager callbacks
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# This module is used to initialize package manager callbacks
require "yast"

module Yast
  class PackageCallbacksInitClass < Module
    def main
      textdomain "base"

      Yast.import "PackageCallbacks"
      PackageCallbacksInit()
    end

    # Register package manager callbacks
    def InitPackageCallbacks
      Builtins.y2warning(
        -1,
        "PackageCallbacksInit::InitPackageCallbacks() is obsoleted, use PackageCallbacks::InitPackageCallbacks() instead"
      )
      PackageCallbacks.InitPackageCallbacks

      nil
    end

    def SetMediaCallbacks
      PackageCallbacks.SetMediaCallbacks

      nil
    end

    def PackageCallbacksInit
      Builtins.y2warning(
        -1,
        "PackageCallbacksInit module is obsoleted, use PackageCallbacks instead"
      )

      nil
    end

    publish function: :InitPackageCallbacks, type: "void ()"
    publish function: :SetMediaCallbacks, type: "void ()"
    publish function: :PackageCallbacksInit, type: "void ()"
  end

  PackageCallbacksInit = PackageCallbacksInitClass.new
  PackageCallbacksInit.main
end
