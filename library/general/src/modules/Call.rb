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
# File:  modules/Call.ycp
# Package:  yast2
# Summary:  Workaround for CallFunction problems
# Authors:  Michal Svec <msvec@suse.cz>
#
# $Id$
require "yast"

module Yast
  class CallClass < Module
    def main; end

    # Workaround function for WFM::CallFunction scope problems (#22486).
    # Same use as WFM::CallFunction.
    # @param [String] function client to be called
    # @param [Array] params
    # @return function result
    def Function(function, params)
      WFM.CallFunction(function, params)
    end

    publish function: :Function, type: "any (string, list)"
  end

  Call = CallClass.new
  Call.main
end
