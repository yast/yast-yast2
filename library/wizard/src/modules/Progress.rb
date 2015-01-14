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
# File:	modules/Progress.ycp
# Module:	Progress
# Summary:	Progress bar
# Authors:	Petr Blahos <pblahos@suse.cz>
#
# $Id$
#
# Functions for progress bar.<br>
# <pre>
# Dialog Title
#
# [x] Stage 1
# [x] Stage 2
#  => Stage 3
#  -  Stage 4
#  -  Stage 5
#
# Progress Title
# [============================90%=======================------]
#
# </pre>
# Example of progress bar usage (don't forget the translation marks in your code):
# Progress bar supposes main wizard dialog is created.<pre>
# Progress::Simple ("Some progress bar", "Progress runs here...", 3, "");
# Progress::NextStep (); // the 1st one does nothing!
# Progress::NextStep ();
# Progress::NextStep ();
# Progress::NextStep ();</pre>
#
# Another example:<pre>
# Progress::New ("Complex progress bar", " ", 100, [
#      "Stage1", "Stage2", "Stage3",
#      ], [
#      "Stage 1 ...", "Stage 2 ...", "Stage 3 ...", "Finished",
#      ], "Help text");
# Progress::NextStage ();
# Progress::NextStageStep (20);
# Progress::Stage (0, "I am back", 2);
# Progress::Title ("Still in stage 0");
# Progress::NextStageStep (90);
# Progress::Finish ();</pre>
#
# It is possible to add a detailed subprogress above the main progress bar:
#
# <pre>
# // create a standard progress
# Progress::New(...);
#
# // add a subprogress with 42 steps
# Progress::SubprogressType(`progress, 42);
# Progress::SubprogressTitle("Subprogress label");
#
# // set the subprogress value
# Progress::SubprogressValue(12);
# Progress::SubprogressValue(24);
#
# // remove the subprogress (it's only for the current task/stage)
# Progress::SubprogressType(`none, nil);
#
# // next stage
# Progress::NextStage();
# </pre>
#
# See also hand made documentation.
# <a href="../Progress.html">Progress.html</a>
require "yast"

module Yast
  class ProgressClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "CommandLine"
      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "Directory"
      Yast.import "FileUtils"

      # *******************************************************************
      # // !!! IMPORTANT !!!
      # // If you add here a new variable which is valid only for the current
      # // progress do not forget to add it to PushState() and PopState()
      # // functions which are are used for nested progresses!
      # *******************************************************************

      # Number of stages.
      @stages = 0
      # Number of steps
      @steps = 0
      # Current stage
      @current_stage = 0
      # Current step
      @current_step = 0
      # list of stage-titles
      @titles = []

      # is progress bar used?
      @visible = true

      # superior progress (stages) bar
      @super_steps = 0
      @super_step = 0
      @super_stages = []

      # remember the last max. value of the subprogress bar
      @last_subprogress_max = 0

      @progress_running = 0

      # remember cumulated number of steps for nested progresses
      @progress_max = 0
      @progress_val = 0

      # stack with the running progresses
      # the top of the stack is the end of the list
      @progress_stack = []

      @global_invisible_icons_definition = []
      @global_visible_icons_definition = []

      @use_icons_in_progress = false
      @has_icon_progress_bar = false

      @last_highlighted_icon = -1
    end

    def IsRunning
      # Check if any progress bar exists. If it does not, we're not running
      # (querying progress counter is not enough, a module ran previously
      # might have failed to reset the counter properly)
      Ops.greater_than(@progress_running, 0) &&
        UI.WidgetExists(:progress_replace_point) == true
    end

    # push the current progress into the stack
    def PushState
      current_subprogress = CurrentSubprogressType()
      state = {
        # global variable
        "stages"               => @stages,
        "steps"                => @steps,
        "current_step"         => @current_step,
        "current_stage"        => @current_stage,
        "titles"               => @titles,
        "last_subprogress_max" => @last_subprogress_max,
        "visible"              => @visible,
        # state of the widgets
        "subprogress_type"     => current_subprogress,
        "progress_label"       => Convert.to_string(
          UI.QueryWidget(Id(:pb), :Label)
        ),
        "progress_value"       => Convert.to_integer(
          UI.QueryWidget(Id(:pb), :Value)
        ),
        "progress_max"         => @progress_max,
        "progress_val"         => @progress_val
      }

      if current_subprogress == :progress
        Ops.set(
          state,
          "subprogress_label",
          Convert.to_string(UI.QueryWidget(Id(:subprogress_progress), :Label))
        )
        Ops.set(
          state,
          "subprogress_value",
          Convert.to_integer(UI.QueryWidget(Id(:subprogress_progress), :Value))
        )
      elsif current_subprogress == :tick
        Ops.set(
          state,
          "subprogress_label",
          Convert.to_string(UI.QueryWidget(Id(:subprogress_tick), :Label))
        )
      end

      Builtins.y2milestone("Current state: %1", state)

      @progress_stack = Builtins.add(@progress_stack, state)

      nil
    end

    # pop the progress state from the stack and set it
    def PopState
      # pop the config
      state = Ops.get(
        @progress_stack,
        Ops.subtract(Builtins.size(@progress_stack), 1),
        {}
      )
      @progress_stack = Builtins.remove(
        @progress_stack,
        Ops.subtract(Builtins.size(@progress_stack), 1)
      )

      Builtins.y2milestone("setting up the previous state: %1", state)

      # refresh the variables
      @stages = Ops.get_integer(state, "stages", 0)
      @steps = Ops.get_integer(state, "steps", 0)
      @current_step = Ops.get_integer(state, "current_step", 0)
      @current_stage = Ops.get_integer(state, "current_stage", 0)
      @titles = Ops.get_list(state, "titles", [])
      @last_subprogress_max = Ops.get_integer(state, "last_subprogress_max", 0)
      @progress_max = Ops.get_integer(state, "progress_max", 0)
      @progress_val = Ops.get_integer(state, "progress_val", 0)

      pb_value = Ops.get_integer(state, "progress_value", 0)
      pb_value = Ops.add(pb_value == nil ? 0 : pb_value, 1)

      # refresh the progress widget, add one step for the embedded progress
      UI.ReplaceWidget(
        Id(:progress_replace_point),
        ProgressBar(
          Id(:pb),
          Ops.get_string(state, "progress_label", ""),
          @steps,
          pb_value
        )
      )

      type = Ops.get_symbol(state, "subprogress_type", :none)
      SubprogressType(type, @last_subprogress_max)

      if type == :progress || type == :tick
        SubprogressTitle(Ops.get_string(state, "subprogress_label", ""))
        SubprogressValue(Ops.get_integer(state, "subprogress_value", 0))
      end

      nil
    end

    # return size of the progress stack
    def StackSize
      Builtins.size(@progress_stack)
    end

    # return the value on the top of the stack
    # the stack is not changed
    def TopState
      Ops.get(
        @progress_stack,
        Ops.subtract(Builtins.size(@progress_stack), 1),
        {}
      )
    end

    # Sets progress bar state:
    # on = normal operation, off = All Progress:: calls return immediatelly.
    # @param [Boolean] state on or off
    # @return previous state
    def set(state)
      prev = @visible
      @visible = state
      prev
    end

    # Returns currently selected visibility status of all UI-modifying Progress:: functions.
    #
    # @return [Boolean] whether the progress bar is used
    # @see #Progress::set
    # @see #Progress::off
    # @see #Progress::on
    def status
      @visible
    end

    # Turns progress bar off. All Progress:: calls return immediatelly.
    # @deprecated set
    def off
      # no "deprecated" warning
      # because it is ok to use this function in testsuites
      @visible = false

      nil
    end

    # Turns progress bar on after calling Progress::off.
    # @deprecated set
    def on
      Builtins.y2warning(-1, "Deprecated function. Use Progress::set instead")
      @visible = true

      nil
    end

    # @param [Symbol] kind `todo, `current or `done
    # @return UI mark for stages
    def Mark(kind)
      return "-" if kind == :todo
      return UI.Glyph(:BulletArrowRight) if kind == :current
      return UI.Glyph(:CheckMark) if kind == :done
      "?@%!"
    end

    # @param [Fixnum] i stage number
    # @return widget `id(...) for the marker
    def MarkId(i)
      Id(Builtins.sformat("mark_stage_%1", i))
    end

    def IconId(i)
      Builtins.sformat("mark_icon_%1", i)
    end

    def FallbackIconInvisible
      Ops.add(Directory.icondir, "32x32/apps/yast-sudo.png")
    end

    def FallbackIconVisible
      Ops.add(Directory.icondir, "32x32/apps/yast-scripts.png")
    end

    def NormalizeIconPath(one_icon, visible)
      if one_icon == nil || one_icon == ""
        one_icon = visible == true ?
          FallbackIconVisible() :
          FallbackIconInvisible()
      end

      if !Builtins.regexpmatch(one_icon, ".[pP][nN][gG]$") &&
          !Builtins.regexpmatch(one_icon, ".[jJ][pP][gG]$")
        one_icon = Ops.add(one_icon, ".png")
      end

      # relative path (to Directory::icondir)
      if Builtins.regexpmatch(one_icon, "/") &&
          !Builtins.regexpmatch(one_icon, "^/")
        one_icon = Ops.add(Directory.icondir, one_icon) 
        # hopefully you know what you do
        # just image name
      elsif !Builtins.regexpmatch(one_icon, "/")
        one_icon = Ops.add(Ops.add(Directory.icondir, "32x32/apps/"), one_icon)
      end

      if !FileUtils.Exists(one_icon)
        Builtins.y2error("Image %1 doesn't exist, using fallback", one_icon)
        one_icon = visible == true ?
          FallbackIconVisible() :
          FallbackIconInvisible()
      end

      one_icon
    end

    def GenerateIdleIcons(number_of_stages)
      display_info = UI.GetDisplayInfo
      can_display_images = Ops.get_boolean(
        display_info,
        "HasImageSupport",
        false
      ) == true

      return Empty() if !can_display_images

      ret = HBox(HSpacing(2))
      i = -1

      number_of_stages = Ops.subtract(number_of_stages, 1)

      while Ops.less_than(i, number_of_stages)
        i = Ops.add(i, 1)

        one_icon = NormalizeIconPath(
          Ops.get(@global_visible_icons_definition, i),
          false
        )
        ret = Builtins.add(
          ret,
          Image(Id(IconId(i)), Opt(:disabled), one_icon, "[X]")
        )
        ret = Builtins.add(ret, HSpacing(2))
      end

      deep_copy(ret)
    end

    # New complex progress bar with stages.
    # @param [String] window_title title of the window
    # @param [String] progress_title title of the progress bar. Pass at least " "
    #                       (one space) if you want some progress bar title.
    # @param [Fixnum] length number of steps. If 0, no progress bar is created,
    #               there are only stages and bottom title. THIS IS NOT
    #               NUMBER OF STAGES!
    # @param [Array<String>] stg list of strings - stage names. If it is nil, then there
    #            are no stages.
    # @param [Array] tits Titles corresponding to stages. When stage changes,
    #             progress bar title changes to one of these titles. May
    #             be nil/empty.
    # @param [String] help_text help text
    def New(window_title, progress_title, length, stg, tits, help_text)
      stg = deep_copy(stg)
      tits = deep_copy(tits)
      return if !@visible

      return if Mode.commandline

      # a progress is already running, remember the current status
      PushState() if IsRunning()

      Builtins.y2milestone(
        "Progress::New(%1, %2, %3)",
        window_title,
        length,
        stg
      )

      orig_current_step = @current_step

      @steps = length
      @stages = Builtins.size(stg)
      @titles = deep_copy(tits)
      @current_step = -1
      @current_stage = -1

      if Ops.less_than(length, Builtins.size(stg))
        Builtins.y2warning(
          "Number of stages (%1) is greater than number of steps (%2)",
          Builtins.size(stg),
          length
        )
      end

      if progress_title == ""
        # Reserve space for future progress bar labels. The ProgressBar
        # widget will suppress the label above the progress bar if the
        # initial label string is empty.
        progress_title = " "
      end

      # do not replace the UI, there is a progress already running
      if IsRunning()
        @progress_max = Ops.multiply(@progress_max, @steps)

        if StackSize() == 1
          @progress_val = Ops.multiply(orig_current_step, @steps)
        else
          prev_state = TopState()
          prev_progress_val = Ops.get_integer(prev_state, "progress_val", 0)

          @progress_val = Ops.multiply(prev_progress_val, @steps)
        end

        # set the maximum value of the progress bar
        UI.ReplaceWidget(
          Id(:progress_replace_point),
          ProgressBar(Id(:pb), progress_title, @progress_max, @progress_val)
        )
        Builtins.y2debug("New progress: %1/%2", @progress_val, @progress_max)

        # increase the reference counter
        @progress_running = Ops.add(@progress_running, 1)
        return
      else
        @progress_max = @steps
      end

      bar = VBox(ProgressBar(Id(:pb), progress_title, length, 0)) # progressbar only
      if 0 != @stages
        bar = VBox(VSpacing(1))
        i = 0
        label_heading = Mark(:todo)

        items = VBox()
        Builtins.foreach(stg) do |item|
          items = Builtins.add(
            items,
            HBox(
              HSpacing(1),
              # check_ycp wants this text to be translatable. I do not know why.
              # HSquash + MinWidth(4) reserves a defined space for 'mark' plus 'emtpy space'
              # see bnc #395752
              HSquash(MinWidth(4, Heading(MarkId(i), label_heading))),
              Label(item),
              HStretch()
            )
          )
          i = Ops.add(i, 1)
        end
        bar = Builtins.add(bar, Left(HBox(HSquash(items))))

        if 0 != @steps
          progress_icons = Empty()
          if @use_icons_in_progress == true
            Builtins.y2milestone("Using icons in progress")
            progress_icons = GenerateIdleIcons(length)
            @has_icon_progress_bar = true
          else
            Builtins.y2milestone("No progress icons defined")
            @has_icon_progress_bar = false
          end

          bar = Builtins.add(
            bar,
            VBox(
              VStretch(),
              progress_icons,
              ReplacePoint(Id(:subprogress_replace_point), Empty()),
              ReplacePoint(
                Id(:progress_replace_point),
                ProgressBar(Id(:pb), progress_title, length, 0)
              ),
              VSpacing(2)
            )
          )
        else
          bar = Builtins.add(
            bar,
            VBox(
              VStretch(),
              ReplacePoint(Id(:subprogress_replace_point), Empty()),
              ReplacePoint(
                Id(:progress_replace_point),
                Label(Id(:pb), Opt(:hstretch), progress_title)
              ),
              VSpacing(2)
            )
          )
        end
      end

      # patch from Michal Srb https://bugzilla.novell.com/show_bug.cgi?id=406890#c7
      if !Mode.test && UI.WidgetExists(Id(:contents))
        UI.ReplaceWidget(Id(:contents), bar)
      end

      if !UI.WizardCommand(term(:SetDialogHeading, window_title))
        UI.ChangeWidget(Id(:title), :Value, window_title)
      end
      Wizard.SetHelpText(help_text) if "" != help_text && nil != help_text
      Wizard.DisableBackButton
      Wizard.DisableNextButton

      @progress_running = Ops.add(@progress_running, 1)

      nil
    end

    # Get current subprogress type
    # @return [Symbol] Current type of the subprogress widget - can be `progress, `tick or `none
    def CurrentSubprogressType
      ret = :none

      return ret if !@visible || Mode.commandline

      # is there the subprogress progress widget?
      if UI.WidgetExists(:subprogress_progress) == true
        ret = :progress
      # or is there the tick subprogress widget?
      elsif UI.WidgetExists(:subprogress_tick) == true
        ret = :tick
      end

      ret
    end

    # Set value of the subprogress
    # @param [Fixnum] value Current value of the subprogress, if a tick subprogress is running the value is ignored and the next tick is displayed
    def SubprogressValue(value)
      return if !@visible || Mode.commandline

      current_type = CurrentSubprogressType()

      # normal progress
      if current_type == :progress
        UI.ChangeWidget(Id(:subprogress_progress), :Value, value)
      # tick progress
      elsif current_type == :tick
        UI.ChangeWidget(Id(:subprogress_tick), :Alive, true)
      else
        Builtins.y2warning("No subprogress is defined, cannot set the value!")
      end

      nil
    end

    # Create (or remove) a new subprogress above the progress bar, can be use for detailed progress of the current task
    # @param [Symbol] type type of the subprogress widget, can be `progress (standard progress),
    # `tick (tick progress) or `none (no subprogress, intended for removing the progress bar from the dialog)
    # @param [Fixnum] max_value maximum value for `progress type, for the other types it is not relevant (use any integer value or nil)
    def SubprogressType(type, max_value)
      return if !@visible || Mode.commandline

      Builtins.y2debug(
        "SubprogressType: type: %1, max_value: %2",
        type,
        max_value
      )

      if type == CurrentSubprogressType()
        if type == :progress
          # just reset the current value of the progress bar if the requested progress is the same
          if max_value == @last_subprogress_max
            Builtins.y2milestone("Resetting the subprogressbar...")
            SubprogressValue(0)
            return
          end
        elsif type == :tick
          # just restart the animation
          UI.ChangeWidget(Id(:subprogress_tick), :Alive, true)
        else
          Builtins.y2milestone("Subprogress initialization skipped")
          return
        end
      end

      widget = Empty()

      if type == :progress
        widget = ProgressBar(Id(:subprogress_progress), " ", max_value, 0)
      elsif type == :tick
        widget = BusyIndicator(Id(:subprogress_tick), " ", 3000)
      elsif type == :none
        widget = Empty()
      else
        Builtins.y2error("Unknown subprogress type: %1", type)
      end

      Builtins.y2debug("widget: %1", widget)
      UI.ReplaceWidget(Id(:subprogress_replace_point), widget)

      # remember the max. value
      @last_subprogress_max = max_value

      nil
    end

    # Set the label of the subprogress
    # @param [String] title New label for the subprogress
    def SubprogressTitle(title)
      return if !@visible || Mode.commandline

      current_type = CurrentSubprogressType()

      if current_type == :progress
        UI.ChangeWidget(Id(:subprogress_progress), :Label, title)
      elsif current_type == :tick
        UI.ChangeWidget(Id(:subprogress_tick), :Label, title)
      else
        Builtins.y2warning("No subprogress is defined, cannot set the label!")
      end

      nil
    end

    # Function adds icon-support to progress dialog.
    # Parameters are the same as for Progress::New() function with one parameter added.
    #
    # @param [String] window_title
    # @param [String] progress_title
    # @param [Fixnum] length
    # @param [Array<String>] stg
    # @param [Array] tits
    # @param [String] help_textmap
    #
    # @param [Array<Array<String>>] icons_definition
    #
    #
    # **Structure:**
    #
    #     icons_definition = $[
    #        [ // first 'visible'
    #          "/path/to/icon-highlighted.png"
    #          "/path/to/another-icon-highlighted.png",
    #        ]
    #        [ // then 'invisible'
    #          "/path/to/icon-gryscale.png",
    #          nil, // fallback icon will be used
    #        ],
    #      ]
    #
    # @see Function Progress::New()
    def NewProgressIcons(window_title, progress_title, length, stg, tits, help_textmap, icons_definition)
      stg = deep_copy(stg)
      tits = deep_copy(tits)
      icons_definition = deep_copy(icons_definition)
      @global_visible_icons_definition = Ops.get(icons_definition, 0, [])
      @global_invisible_icons_definition = Ops.get(icons_definition, 1, [])

      @use_icons_in_progress = true
      New(window_title, progress_title, length, stg, tits, help_textmap)
      @use_icons_in_progress = false

      nil
    end

    # Create simple progress bar with no stages, only with progress bar.
    # @param [String] window_title Title of the window.
    # @param [String] progress_title Title of the progress bar.
    # @param [Fixnum] length Number of steps.
    # @param [String] help_text Help text.
    def Simple(window_title, progress_title, length, help_text)
      New(window_title, progress_title, length, [], [], help_text)

      nil
    end

    # Highlights a progress icon (changes the dimmed one
    # into a normal one).
    #
    # @param integer current step ID
    def HighlightProgressIcon(step_id)
      if @has_icon_progress_bar
        @last_highlighted_icon = -1 if @last_highlighted_icon == nil

        # some steps might have been skipped, change all (not changed yet)
        # icons one by one
        while Ops.less_than(@last_highlighted_icon, step_id)
          @last_highlighted_icon = Ops.add(@last_highlighted_icon, 1)

          icon_id = IconId(@last_highlighted_icon)

          if UI.WidgetExists(Id(icon_id)) == true
            UI.ChangeWidget(Id(icon_id), :Enabled, true)
          end
        end
      end

      nil
    end

    # Uses current_step
    def UpdateProgressBar
      if Ops.greater_than(@current_step, @steps)
        Builtins.y2error(
          -2,
          "Progress bar has only %1 steps, not %2.",
          @steps,
          @current_step
        )
        return
      end

      progress_value = @current_step

      # do not change icons in a nested progress
      if StackSize() == 0
        HighlightProgressIcon(@current_step)
      else
        # recalculate the progress bar value according to the parent progress
        prev_state = TopState()
        prev_step = Ops.get_integer(prev_state, "current_step", 0)

        progress_value = Ops.add(
          Ops.multiply(prev_step, @steps),
          Ops.greater_than(@current_step, 0) ? @current_step : 0
        )
      end

      Builtins.y2debug(
        "New progress value: %1, current_step: %2/%3 (%4%%)",
        progress_value,
        @current_step,
        @steps,
        Ops.divide(
          Ops.multiply(
            100.0,
            Convert.convert(progress_value, from: "integer", to: "float")
          ),
          Convert.convert(@progress_max, from: "integer", to: "float")
        )
      )

      UI.ChangeWidget(Id(:pb), :Value, progress_value)

      nil
    end

    # the bar is either `ProgressBar or `Label
    # @param [String] s title
    def SetProgressBarTitle(s)
      UI.ChangeWidget(Id(:pb), 0 == @steps ? :Value : :Label, s)

      nil
    end

    # Some people say it is the best operating system ever. But now to the
    # function. Advances progress bar value by 1.
    def NextStep
      return if !@visible || Mode.commandline || 0 == @steps
      @current_step = Ops.add(@current_step, 1)
      UpdateProgressBar()

      nil
    end

    # Advance stage, advance step by 1 and set progress bar caption to
    # that defined in New.
    def NextStage
      return if !@visible
      NextStep()

      if 0 == @stages || Ops.greater_than(@current_stage, @stages)
        Builtins.y2error("Non-existing stage requested.")
        return
      end

      @current_stage = Ops.add(@current_stage, 1)

      # do not update the UI in a nested progress
      return if Ops.greater_than(StackSize(), 0)

      if Mode.commandline
        if Ops.less_than(@current_stage, @stages) &&
            Ops.less_than(@current_stage, Builtins.size(@titles))
          CommandLine.PrintVerbose(Ops.get_string(@titles, @current_stage, ""))
        end
        return
      end

      if Ops.greater_than(@current_stage, 0)
        UI.ChangeWidget(
          MarkId(Ops.subtract(@current_stage, 1)),
          :Value,
          Mark(:done)
        )
      end
      # we may be past the last stage
      if Ops.less_than(@current_stage, @stages)
        if Ops.less_than(@current_stage, Builtins.size(@titles))
          SetProgressBarTitle(Ops.get_string(@titles, @current_stage, ""))
        end
        UI.ChangeWidget(MarkId(@current_stage), :Value, Mark(:current))
      end

      nil
    end
    # Changes progress bar value to st.
    # @param [Fixnum] st new value
    def Step(st)
      return if !@visible || Mode.commandline || 0 == @steps

      return if Ops.less_than(st, 0) || Ops.greater_than(st, @steps)

      @current_step = st

      UpdateProgressBar()

      nil
    end

    # Go to stage st, change progress bar title to title and set progress
    # bar step to step.
    # @param [Fixnum] st New stage.
    # @param [String] title New title for progress bar. If nil, title specified in
    #              New is used.
    # @param [Fixnum] step New step or -1 if step should not change.
    def Stage(st, title, step)
      return if !@visible

      Step(step) if -1 != step

      # another progress is running
      # do not change the current stage, calculate the target step
      if Ops.greater_than(StackSize(), 0)
        UpdateProgressBar()
        return
      end

      if !Mode.commandline && Ops.greater_or_equal(@current_stage, 0)
        UI.ChangeWidget(
          MarkId(@current_stage),
          :Value,
          Mark(Ops.greater_than(st, @current_stage) ? :done : :todo)
        )
      end

      @current_stage = st
      s = ""
      if Ops.less_than(@current_stage, Builtins.size(@titles))
        s = Ops.get_string(@titles, @current_stage, "")
      end
      s = title if nil != title
      if Ops.less_than(@current_stage, Builtins.size(@titles))
        if Mode.commandline
          CommandLine.PrintVerbose(s)
          return
        else
          SetProgressBarTitle(s)
        end
      end
      if Ops.less_than(@current_stage, @stages)
        UI.ChangeWidget(MarkId(@current_stage), :Value, Mark(:current))
      end

      nil
    end

    # Jumps to the next stage and sets step to st.
    # @param [Fixnum] st new progress bar value
    def NextStageStep(st)
      return if !@visible || Mode.commandline
      NextStage()
      Step(st)

      nil
    end

    # Change progress bar title.
    # @param [String] t new title. Use ""(empty string) if you want an empty progress bar.
    def Title(t)
      SetProgressBarTitle(t) if @visible && !Mode.commandline

      nil
    end

    # Moves progress bar to the end and marks all stages as completed.
    def Finish
      return if !@visible || Mode.commandline

      # decrease the reference counter
      @progress_running = Ops.subtract(@progress_running, 1)

      # set the previous state
      if Ops.greater_than(StackSize(), 0)
        PopState()
        return
      end

      if 0 != @stages
        while Ops.less_than(@current_stage, @stages)
          NextStage()
        end
      end
      if 0 != @steps
        @current_step = @steps
        UpdateProgressBar()
      end

      SetProgressBarTitle(" ")

      nil
    end

    # Creates a higher-level progress bar made of stages. Currently it is
    # placed instead of help text.
    # @param [String] title title of the progress...
    # @param [Array<String>] stages list of stage descriptions
    def OpenSuperior(title, stages)
      stages = deep_copy(stages)
      if UI.HasSpecialWidget(:Wizard)
        Wizard.OpenAcceptAbortStepsDialog
        UI.WizardCommand(term(:AddStepHeading, title))

        idx = 0
        @super_steps = Builtins.size(stages)
        @super_step = -1
        Builtins.foreach(stages) do |s|
          id = Builtins.sformat("super_progress_%1", idx)
          UI.WizardCommand(term(:AddStep, s, id))
        end
        UI.WizardCommand(term(:UpdateSteps)) # old behaviour
      else
        left = VBox(VStretch())
        right = VBox(VStretch())
        idx = 0
        @super_steps = Builtins.size(stages)
        @super_step = -1
        Builtins.foreach(stages) do |i|
          id = Builtins.sformat("super_progress_%1", idx)
          left = Builtins.add(left, Heading(Id(id), "-  "))
          right = Builtins.add(right, Label(Opt(:hstretch), i))
          left = Builtins.add(left, VStretch())
          right = Builtins.add(right, VStretch())
          idx = Ops.add(idx, 1)
        end
        left = Builtins.add(left, HSpacing(4))
        right = Builtins.add(right, HStretch())
        Wizard.ReplaceHelp(
          VBox(
            HBox(HSpacing(1), Frame(title, HBox(HSpacing(1), left, right))),
            VSpacing(0.5)
          )
        )
      end

      nil
    end
    # Replaces stages of superior progress by an empty help text.
    def CloseSuperior
      if UI.HasSpecialWidget(:Wizard)
        UI.CloseDialog
      else
        Wizard.RestoreHelp("")
      end
      @super_steps = 0
      @super_step = 0

      nil
    end
    # Make one step in a superior progress bar.
    def StepSuperior
      if Ops.greater_or_equal(@super_step, 0) &&
          Ops.less_than(@super_step, @super_steps)
        if !UI.HasSpecialWidget(:Wizard)
          UI.ChangeWidget(
            Id(Builtins.sformat("super_progress_%1", @super_step)),
            :Value,
            UI.Glyph(:CheckMark)
          )
        end
      end
      @super_step = Ops.add(@super_step, 1)
      return if Ops.greater_or_equal(@super_step, @super_steps)
      if UI.HasSpecialWidget(:Wizard)
        UI.WizardCommand(
          term(
            :SetCurrentStep,
            Builtins.sformat("super_progress_%1", @super_step)
          )
        )
      else
        UI.ChangeWidget(
          Id(Builtins.sformat("super_progress_%1", @super_step)),
          :Value,
          UI.Glyph(:BulletArrowRight)
        )
      end

      nil
    end

    publish function: :IsRunning, type: "boolean ()"
    publish function: :CurrentSubprogressType, type: "symbol ()"
    publish function: :SubprogressTitle, type: "void (string)"
    publish function: :SubprogressValue, type: "void (integer)"
    publish function: :SubprogressType, type: "void (symbol, integer)"
    publish function: :set, type: "boolean (boolean)"
    publish function: :status, type: "boolean ()"
    publish function: :off, type: "void ()"
    publish function: :on, type: "void ()"
    publish function: :New, type: "void (string, string, integer, list <string>, list, string)"
    publish function: :NewProgressIcons, type: "void (string, string, integer, list <string>, list, string, list <list <string>>)"
    publish function: :Simple, type: "void (string, string, integer, string)"
    publish function: :NextStep, type: "void ()"
    publish function: :NextStage, type: "void ()"
    publish function: :Step, type: "void (integer)"
    publish function: :Stage, type: "void (integer, string, integer)"
    publish function: :NextStageStep, type: "void (integer)"
    publish function: :Title, type: "void (string)"
    publish function: :Finish, type: "void ()"
    publish function: :OpenSuperior, type: "void (string, list <string>)"
    publish function: :CloseSuperior, type: "void ()"
    publish function: :StepSuperior, type: "void ()"
  end

  Progress = ProgressClass.new
  Progress.main
end
