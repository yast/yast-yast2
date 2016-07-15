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
  class T2Client < Client
    def main
      #    global define void UI::OpenDialog (term t) ``{};
      #    global define void UI::CloseDialog () ``{};
      #    global define symbol UI::UserInput()``{return `_tp_cancel ;}

      Yast.include self, "testsuite.rb"
      Yast.import "CWM"
      Yast.import "TablePopup"
      Yast.import "Report"

      # disable use of UI
      Report.Import("errors" => { "show" => false, "log" => true })

      Yast.include self, "testfunc.rb"
      Yast.import "Mode"

      Mode.SetTest("testsuite")

      @functions = {
        "init"  => fun_ref(method(:generic_init), "void (string)"),
        "store" => fun_ref(method(:generic_save), "void (string, map)")
      }

      @ret = nil

      DUMP("=========================================")
      DUMP("============   Table/Popup   ============")
      DUMP("=========================================")

      @widgets = { "table" => MyCreateTable() }
      @widget_data = CWM.CreateWidgets(["table"], @widgets)
      DUMP(Builtins.sformat("W: %1", Ops.get(@widget_data, 0)))

      DUMP("=========================================")
      DUMP("Init")
      CWM.initWidgets(@widget_data)

      DUMP("=========================================")
      DUMP("Handle")

      @ret = CWM.handleWidgets(@widget_data, "ID" => :_tp_edit)
      DUMP(Builtins.sformat("Returned %1", @ret))
      Ops.set(
        @widget_data,
        [0, "options", "a", "table", "handle"],
        fun_ref(method(:a_handle), "symbol (any, string, map)")
      )
      @ret = CWM.handleWidgets(@widget_data, "ID" => :_tp_edit)
      DUMP(Builtins.sformat("Returned %1", @ret))

      DUMP("=========================================")
      DUMP("Popups")
      DUMP("======")

      DUMP("========================================")
      DUMP("Merge functions")
      @option = TablePopup.key2descr(Ops.get(@widget_data, 0, {}), "a")
      DUMP(Builtins.sformat("Before: %1", @option))
      @option = TablePopup.updateOptionMap(
        @option,
        Ops.get_map(@widget_data, [0, "fallback"], {})
      )
      DUMP(Builtins.sformat("After: %1", @option))

      DUMP("=========================================")
      DUMP("Prepare widget")
      @popup = Ops.get_map(@option, "popup", {})
      @popup = Builtins.add(@popup, "____", "____") # needed just to create a real copy
      @popup = CWM.prepareWidget(@popup)
      @popup = Builtins.remove(@popup, "____")
      DUMP(Builtins.sformat("Prepared: %1", @popup))

      DUMP("=========================================")
      DUMP("Run popup")

      TablePopup.singleOptionEditPopup(@option)

      nil
    end

    def MyCreateTable
      ret = TablePopup.CreateTableDescr(
        {},

        "init"     => fun_ref(
          TablePopup.method(:TableInitWrapper),
          "void (string)"
        ),
        "handle"   => fun_ref(
          TablePopup.method(:TableHandleWrapper),
          "symbol (string, map)"
        ),
        "ids"      => fun_ref(method(:getIdList), "list (map)"),
        "id2key"   => fun_ref(method(:id2key), "string (map, any)"),
        "options"  => @popups,
        "fallback" => {
          "init"    => fun_ref(method(:fallback_init), "void (any, string)"),
          "store"   => fun_ref(method(:fallback_store), "void (any, string)"),
          "summary" => fun_ref(
            method(:fallback_summary),
            "string (any, string)"
          )
        }

      )
      deep_copy(ret)
    end
  end
end

Yast::T2Client.new.main
