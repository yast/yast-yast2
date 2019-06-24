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
# File:  Event.ycp
# Package:  yast2
# Summary:  UI Event Helpers
# Authors:  Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class EventClass < Module
    # Returns id of widget causing the event.
    def GetWidgetId(event)
      event = deep_copy(event)
      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is WidgetEvent and the EventReason is
    # Activated.
    #
    # Returns id or nil.
    def IsWidgetActivated(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "WidgetEvent"
        return nil
      end

      if Ops.get_string(event, "EventReason", "Unknown") != "Activated"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is WidgetEvent and the EventReason is
    # SelectionChanged.
    #
    # Returns id or nil.
    def IsWidgetSelectionChanged(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "WidgetEvent"
        return nil
      end

      if Ops.get_string(event, "EventReason", "Unknown") != "SelectionChanged"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is WidgetEvent and the EventReason is
    # ValueChanged.
    #
    # Returns id or nil.
    def IsWidgetValueChanged(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "WidgetEvent"
        return nil
      end

      if Ops.get_string(event, "EventReason", "Unknown") != "ValueChanged"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is WidgetEvent and the EventReason is
    # Activated or SelectionChanged.
    #
    # Returns id or nil.
    def IsWidgetActivatedOrSelectionChanged(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "WidgetEvent"
        return nil
      end

      if Ops.get_string(event, "EventReason", "Unknown") != "Activated" &&
          Ops.get_string(event, "EventReason", "Unknown") != "SelectionChanged"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is WidgetEvent and the EventReason is
    # ContextMenuActivated.
    #
    # Returns id or nil.
    def IsWidgetContextMenuActivated(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "WidgetEvent"
        return nil
      end

      if Ops.get_string(event, "EventReason", "Unknown") !=
          "ContextMenuActivated"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is MenuEvent.
    #
    # return id or nil.
    def IsMenu(event)
      event = deep_copy(event)
      return nil if Ops.get_string(event, "EventType", "Unknown") != "MenuEvent"

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is TimeoutEvent.
    #
    # return id or nil.
    def IsTimeout(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "TimeoutEvent"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    # Checks that the EventType is CancelEvent.
    #
    # return id or nil.
    def IsCancel(event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventType", "Unknown") != "CancelEvent"
        return nil
      end

      Ops.get_symbol(event, "ID")
    end

    publish function: :GetWidgetId, type: "symbol (map)"
    publish function: :IsWidgetActivated, type: "symbol (map)"
    publish function: :IsWidgetSelectionChanged, type: "symbol (map)"
    publish function: :IsWidgetValueChanged, type: "symbol (map)"
    publish function: :IsWidgetActivatedOrSelectionChanged, type: "symbol (map)"
    publish function: :IsWidgetContextMenuActivated, type: "symbol (map)"
    publish function: :IsMenu, type: "symbol (map)"
    publish function: :IsTimeout, type: "symbol (map)"
    publish function: :IsCancel, type: "symbol (map)"
  end

  Event = EventClass.new
end
