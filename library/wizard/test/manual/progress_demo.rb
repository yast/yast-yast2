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

#---------------------------------------------------------------------------
#
# Manual demo and testing client for the Progress.rb module
#
# Start with
#
#   yast2 ./progress_demo
#
# and click though the application. Use the "Next Step", "Next Stage", "Next
# Stage Step" buttons to trigger the progress update methods of the Progress
# module directly.
#
# Use "Open Popup" to open a popup like in the libzypp callbacks (you can open
# several of them) and "Close Popup" to close the toplevel layer of popups
# again. Use the "Next XZ" buttons from there to check what happens if the
# progress is updated while one of those popups is open: It shouldn't crash
# with a UI error (bsc#1187676), though it may leave the progress somewhat
# disturbed visually afterwards.
#
# Implementation details: This uses a normal UI dialog, not, as the Progress
# module expects, a wizard dialog: It would completely exchange the content of
# the wizard dialog, removing the buttons that we added for the purpose of this
# test, which would make the test unusable.

require "yast"

module Yast

  class ProgressDemo < Client
    include Yast::Logger

    attr_accessor :progress_type

    def initialize
      Yast.import "UI"
      Yast.import "Progress"

      @popup_count = 0
      @progress_type = :simple
    end

    def run
      UI.OpenDialog(content)
      add_progress
      handle_events
      UI.CloseDialog
    end

    def content
      MinSize(
        Id(:main_dialog),
        80, 20,
        MarginBox(
          2, 0.45,
          HBox(
            HVCenter(
              # This emulates the inner part of a wizard dialog
              # which we can't use to avoid our buttons being removed
              ReplacePoint(Id(:contents), Empty())
            ),
            HSpacing(3),
            main_buttons
          )
        )
      )
    end

    def add_progress
      case @progress_type
      when :simple
        simple_progress
      when :complex, nil
        complex_progress
      end
    end

    def simple_progress
      window_title = "" # unused
      progress_title = "Some Progress..."
      progress_len = 7
      help_text = ""

      Progress.Simple(
        window_title,
        progress_title,
        progress_len,
        help_text
      )
    end

    def complex_progress
      window_title = "" # unused
      progress_title = "Complex Progress..."
      help_text = ""

      stages = ["Stage 1", "Stage 2", "Stage 3", "Stage 4"]
      titles = ["Title 1", "Title 2", "Title 3", "Title 4"]
      progress_len = 3 * stages.size

      Progress.New(
        window_title,
        progress_title,
        progress_len,
        stages,
        titles,
        help_text
      )
      Progress.NextStage
    end

    def main_buttons
      HSquash(
        VBox(
          VStretch(),
          *common_buttons,
          VStretch(),
          PushButton(Id(:quit), Opt(:hstretch), "&Quit")
        )
      )
    end

    def common_buttons
      # Opt(:hstretch) makes all buttons the same width if put in a vertical
      # column (as used in the main dialog). It has no effect if they are put
      # in a horizontal row (as used in the popup dialog).
      opt = Opt(:hstretch)

      [
        PushButton(Id(:next_step), opt, "&Next Step"),
        PushButton(Id(:next_stage), opt, "Next &Stage"),
        PushButton(Id(:next_stage_step), opt, "Next Stage St&ep"),
        PushButton(Id(:open_popup), opt, "&Open Popup")
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
        when :next_step
          Progress.NextStep
        when :next_stage
          Progress.NextStage
        when :next_stage_step
          Progress.NextStageStep(1)
        end

        input
      end
    end

    # Open a dialog to ask the user which progress type to use and set the
    # internal @progress_type member variable accordingly.
    def select_progress_type
      UI.OpenDialog(
        MarginBox(
          1, 0.45,
          MinWidth(
            20,
            VBox(
              SelectionBox(
                Id(:progress_type),
                "Progress &Type",
                [
                  Item(Id(:simple), "Simple", true),
                  Item(Id(:complex), "Complex")
                ]
              ),
              Right(PushButton("C&ontinue"))
            )
          )
        )
      )
      UI.UserInput
      # Query the widget as long as the dialog is still open
      @progress_type = UI.QueryWidget(Id(:progress_type), :Value)
      UI.CloseDialog
      @progress_type
    end
  end
end

client = Yast::ProgressDemo.new
# Comment the next line out to avoid the initial question
client.select_progress_type
client.run
