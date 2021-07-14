#!/usr/bin/env ruby

# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

#
# Manual demo and testing client for the Progress.rb module
#
# Start with
#
#   yast2 ./progress_demo
#
# and click though the application.
#

require "yast"

module Yast

  class ProgressDemo < Client
    include Yast::Logger

    def initialize
      Yast.import "UI"

      @popup_count = 0
    end

    def run
      UI.OpenDialog(content)
      handle_events
      UI.CloseDialog
    end

    def content
      MinSize(
        Id(:main_dialog),
        60, 20,
        MarginBox(
          2, 0.45,
          VBox(
            HVCenter(
              Label("Hello, World!")
            ),
            main_buttons
          )
        )
      )
    end

    def main_buttons
      HBox(
        HStretch(),
        *common_buttons,
        HSpacing(3),
        PushButton(Id(:quit), "&Quit")
      )
    end

    def common_buttons
      [
        PushButton(Id(:progress), "&Progress"),
        PushButton(Id(:open_popup), "&Open Popup")
      ]
    end

    def open_popup
      @popup_count += 1
      UI.OpenDialog(popup_content)
    end

    def popup?
      UI.WidgetExists(:popup_dialog)
    end

    def close_popup
      if popup?
        UI.CloseDialog
        @popup_count -= 1
      else
        log.warn("No popup dialog to close")
      end
    end

    def popup_content
      MarginBox(
        Id(:popup_dialog),
        2, 0.45,
        VBox(
          HVCenter(
            Label("Popup dialog ##{@popup_count} that gets in the way")
          ),
          popup_buttons
        )
      )
    end

    def popup_buttons
      HBox(
        HStretch(),
        *common_buttons,
        PushButton(Id(:close_popup), "&Close Popup"),
        HStretch()
      )
    end

    # Event handler for the main dialog as well as for any open popups
    def handle_events
      while true
        input = UI.UserInput
        log.info("Input: \"#{input}\"")

        case input
        when :quit
          break # leave event loop
        when :open_popup
          open_popup
        when :close_popup
          close_popup
        when :cancel # :cancel is WM_CLOSE
          if popup?
            close_popup
          else
            break # leave event loop
          end
        end

        input
      end
    end
  end
end

Yast::ProgressDemo.new.run
