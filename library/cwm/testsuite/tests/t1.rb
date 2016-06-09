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
# File:
#  t1.ycp
#
# Module:
#  Common Widget Manipulation
#
# Summary:
#  Common Widget Manipulation tests
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# testedfiles: CWM.ycp testfunc.yh Testsuite.ycp
module Yast
  class T1Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "CWM"
      Yast.import "Report"

      # disable use of UI
      Report.Import("errors" => { "show" => false, "log" => true })

      Yast.include self, "testfunc.rb"

      @functions = {
        "init"  => fun_ref(method(:generic_init), "void (string)"),
        "store" => fun_ref(method(:generic_save), "void (string, map)")
      }

      @widget_names = ["w1", "w2"]

      @ret = nil

      DUMP("========================================")
      DUMP("==========   Common stuff   ============")
      DUMP("========================================")

      @widget_data = CWM.CreateWidgets(@widget_names, @widgets)
      DUMP(Builtins.sformat("W1: %1", Ops.get(@widget_data, 0)))
      DUMP(Builtins.sformat("W2: %1", Ops.get(@widget_data, 1)))

      DUMP("========================================")
      DUMP("Merge functions")
      @widget_data = CWM.mergeFunctions(@widget_data, @functions)
      DUMP(Builtins.sformat("Merged W1: %1", Ops.get(@widget_data, 0)))
      DUMP(Builtins.sformat("Merged W2: %1", Ops.get(@widget_data, 1)))

      DUMP("=========================================")
      DUMP("Init")

      CWM.initWidgets(@widget_data)

      DUMP("=========================================")
      DUMP("Handle")

      DUMP("- Both will run")
      @ret = CWM.handleWidgets(@widget_data, "ID" => :event)
      DUMP(Builtins.sformat("Returned %1", @ret))
      DUMP("- First causes event loop finish")
      Ops.set(
        @widget_data,
        [0, "handle"],
        fun_ref(method(:w1_handle_symbol), "symbol (string, map)")
      )
      @ret = CWM.handleWidgets(@widget_data, "ID" => :event)
      DUMP(Builtins.sformat("Returned %1", @ret))

      DUMP("=========================================")
      DUMP("Validate")
      DUMP("- Run both")
      @ret = CWM.validateWidgets(@widget_data, "ID" => :event)
      DUMP(Builtins.sformat("Returned %1", @ret))
      DUMP("- First fails")
      Ops.set(
        @widget_data,
        [0, "validate_function"],
        fun_ref(method(:w1_validat_false), "boolean (string, map)")
      )
      @ret = CWM.validateWidgets(@widget_data, "ID" => :event)
      DUMP(Builtins.sformat("Returned %1", @ret))

      DUMP("=========================================")
      DUMP("Save")
      CWM.saveWidgets(@widget_data, "ID" => :event)

      nil
    end
  end
end

Yast::T1Client.new.main
