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
# File:	clients/menu.ycp
# Module:	yast2
# Summary:	NCurses Control Center
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Provides a list of available yast2 modules. This module is inteded for use
# with ncurses, for X the yast2 control center should be used.
module Yast
  class MenuClient < Client
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Desktop"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Popup"

      @Groups = {}
      @Modules = {}
      @root = false

      @restart_file = Ops.add(Directory.vardir, "/restart_menu")
      # file existing if yast2-online-update wants to be restarted
      @restart_you = Ops.add(Directory.vardir, "/selected_patches.ycp")

      DisplaySplash()

      @Values = [
        "Name",
        # not required: "GenericName",
        "X-SuSE-YaST-Argument",
        "X-SuSE-YaST-Call",
        "X-SuSE-YaST-Group",
        "X-SuSE-YaST-SortKey",
        "X-SuSE-YaST-RootOnly",
        "Hidden"
      ]

      Desktop.Read(@Values)
      @Groups = deep_copy(Desktop.Groups)
      @Modules = deep_copy(Desktop.Modules)
      Builtins.y2debug("Groups=%1", @Groups)
      Builtins.y2debug("Modules=%1", @Modules)

      @non_root_modules = []

      #create the list of modules available to non-root users
      Builtins.foreach(
        Convert.convert(@Modules, from: "map", to: "map <string, map>")
      ) do |name, params|
        if !(Ops.get_string(params, "X-SuSE-YaST-RootOnly", "false") == "true")
          @non_root_modules = Builtins.add(@non_root_modules, name)
        end
      end
      Builtins.y2debug("non-root modules: %1", @non_root_modules)

      if FileUtils.Exists(@restart_file)
        SCR.Execute(path(".target.remove"), @restart_file)
      end

      UI.CloseDialog

      OpenMenu()

      @GroupList = Desktop.GroupList

      # precache groups (#38363)
      @groups = Builtins.maplist(@GroupList) { |gr| Ops.get_string(gr, [0, 0]) }
      Builtins.y2debug("groups=%1", @groups)

      @modules = Builtins.listmap(@groups) do |gr|
        all_modules = Desktop.ModuleList(gr)
        #filter out root-only stuff if the user is not root (#246015)
        all_modules = Builtins.filter(all_modules) do |t|
          Builtins.contains(@non_root_modules, Ops.get_string(t, [0, 0], ""))
        end if !@root
        { gr => all_modules }
      end
      Builtins.y2debug("modules=%1", @modules)

      @first = Ops.get(@groups, 0)
      Builtins.y2debug("first=%1", @first)

      #do not show groups containing no modules to the user (#309452)
      @GroupList = Builtins.filter(@GroupList) do |t|
        group = Ops.get_string(t, [0, 0], "")
        Ops.get(@modules, group) != []
      end

      # GroupList = [`item (`id ("Software"), "Software"), ...]
      UI.ReplaceWidget(
        Id(:groups_rep),
        SelectionBox(
          Id(:groups),
          Opt(:notify, :immediate, :keyEvents),
          "",
          @GroupList
        )
      )
      Builtins.y2debug("GroupList=%1", @GroupList)

      ReplaceModuleList(@first)
      UI.SetFocus(Id(:groups))

      while true
        @event = UI.WaitForEvent
        @eventid = Ops.get(@event, "ID")
        # y2debug too constly: y2debug("event=%1", event);

        if Ops.is_symbol?(@eventid)
          if @eventid == :groups &&
              Ops.get_string(@event, "EventReason", "") == "SelectionChanged"
            @id = Convert.to_string(UI.QueryWidget(Id(:groups), :CurrentItem))
            # ReplaceModuleList(id);
            UI.ReplaceWidget(
              Id(:progs_rep),
              SelectionBox(
                Id(:progs),
                Opt(:notify, :keyEvents),
                "",
                Ops.get(@modules, @id, [])
              )
            )
            next
          elsif ( @eventid == :progs || @eventid == :run ) &&
              Ops.get_string(@event, "EventReason", "") == "Activated"
            @program = Convert.to_string(
              UI.QueryWidget(Id(:progs), :CurrentItem)
            )
            break if Launch(@program)
          elsif @eventid == :groups &&
              Ops.get_string(@event, "EventReason", "") == "Activated"
            UI.SetFocus(Id(:progs))
          elsif @eventid == :help
            ShowNcursesHelp()
          elsif @eventid == :quit || @eventid == :cancel
            break
          else
            Builtins.y2warning("Event or widget ID not handled: %1", @event)
          end
        elsif Ops.is_string?(@eventid)
          if Ops.get_symbol(@event, "FocusWidgetID", :none) == :groups &&
              @eventid == "CursorRight"
            UI.SetFocus(Id(:progs))
          elsif Ops.get_symbol(@event, "FocusWidgetID", :none) == :progs &&
              @eventid == "CursorLeft"
            UI.SetFocus(Id(:groups))
          else
            Builtins.y2warning("Event or widget ID not handled: %1", @event)
          end
        else
          Builtins.y2warning("Event or widget ID not handled: %1", @event)
        end
      end

      UI.CloseDialog 

      # EOF

      nil
    end

    def DisplaySplash
      UI.OpenDialog(
        Opt(:defaultsize),
        VBox(
          VStretch(),
          # Message shown while loading modules information
          Label(_("Loading modules, please wait ...")),
          VStretch()
        )
      )

      nil
    end

    def OpenMenu
      #check if user is root (#246015)
      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/id --user")
      )
      @root = Ops.get_string(output, "stdout", "") == "0\n"

      UI.OpenDialog(
        Opt(:defaultsize),
        VBox(
          HBox(
            HSpacing(1),
            Frame(
              "",
              VBox(
                VSpacing(0.4),
                HBox(
                  HSpacing(2),
                  # Heading for NCurses Control Center
                  HCenter(Heading(_("YaST Control Center"))),
                  HSpacing(2)
                ),
                VSpacing(0.4)
              )
            ),
            HSpacing(1.5)
          ),
          VSpacing(1.0),
          HBox(
            HSpacing(1),
            HWeight(
              30,
              ReplacePoint(
                Id(:groups_rep),
                SelectionBox(
                  Id(:groups),
                  Opt(:notify, :immediate, :keyEvents),
                  "",
                  []
                )
              )
            ),
            HSpacing(1),
            HWeight(
              70,
              ReplacePoint(
                Id(:progs_rep),
                SelectionBox(Id(:progs), Opt(:notify, :keyEvents), "", [])
              )
            ),
            HSpacing(1)
          ),
          VSpacing(1.0),
          HBox(
            HSpacing(1),
            PushButton(Id(:help), Opt(:key_F1, :helpButton), Label.HelpButton),
            HStretch(),
            PushButton(Id(:run), Opt(:defaultButton), _("Run")),
            PushButton(Id(:quit), Opt(:key_F9, :cancelButton), Label.QuitButton),
            HSpacing(1)
          ),
          VSpacing(1)
        )
      )

      #show popup when running as non-root
      if !@root
        Popup.Notify(
          _(
            "YaST2 Control Center is not running as root.\nYou can only see modules that do not require root privileges."
          )
        )
      end

      nil
    end

    # @return [Boolean] true if control center is to be resatrted
    def Launch(modul)
      function = Ops.get_string(@Modules, [modul, "X-SuSE-YaST-Call"], "")
      argument = Ops.get_string(@Modules, [modul, "X-SuSE-YaST-Argument"], "")
      Builtins.y2debug("Calling: %1 (%2)", function, argument)

      display_info = UI.GetDisplayInfo
      textmode = Ops.get_boolean(display_info, "TextMode", false)

      if function != ""
        cmd = ""
        ret = nil

        #Use UI::RunInTerminal in text-mode only (#237332)
        if textmode
          cmd = Builtins.sformat("/sbin/yast %1 %2 >&2", function, argument)
          ret = UI.RunInTerminal(cmd)
        else
          cmd = Builtins.sformat("/sbin/yast2 %1 %2 >&2", function, argument)
          ret = SCR.Execute(path(".target.bash"), cmd)
        end
        Builtins.y2milestone("Got %1 from %2", ret, cmd)

        if function == "online_update" && ret != :cancel && ret != :abort &&
            FileUtils.Exists(@restart_you)
          Builtins.y2milestone("yast needs to be restarted - exiting...")
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("touch %1", @restart_file)
          )
          return true
        end
      end
      false
    end

    def ShowNcursesHelp
      # NCurses (textmode) Control Center headline
      headline = _("Controlling YaST ncurses with the Keyboard")

      # NCurses Control Center help 1/
      help = _(
        "<p>1) <i>General</i><br>\n" \
          "Navigate through the dialog elements with [TAB] to go to\n" \
          "the next element and [SHIFT] (or [ALT]) + [TAB] to move backwards.\n" \
          "Select or activate elements with [SPACE] or [ENTER].\n" \
          "Some elements use arrow keys (e.g., to scroll in lists).</p>"
      ) +
        # NCurses Control Center help 2/10
        _(
          "<p>Tree navigation is also done by arrow keys. To open or close a " \
          "branch use [SPACE]. For modules showing a tree (might look like a list) " \
          "of configuration items on the left side use [ENTER] to get corresponding " \
          "dialog on the right.</p>"
        ) +
        # NCurses Control Center help 3/10
        _(
          "<p>Buttons are equipped with shortcut keys (the highlighted\nletter). Use [ALT] and the letter to activate the button.</p>"
        ) +
        # NCurses Control Center help 4/10
        _(
          "<p>Press [ESC] to close selection pop-ups (e.g., from\nmenu buttons) without choosing anything.</p>\n"
        ) +
        # NCurses Control Center help 5/10
        _(
          "<p>2) <i>Substitution of Keystrokes</i><br>\n" \
            "<p>Because the environment can affect the use of the keyboard,\n" \
            "there is more than one way to navigate the dialog pages.\n" \
            "If [TAB] and [SHIFT] (or [ALT]) + [TAB] do not work,\n" \
            "move focus forward with [CTRL] + [F] and backward with [CTRL] + [B].</p>"
        ) +
        # NCurses Control Center help 6/10
        _(
          "<p>If [ALT] + [letter] does not work,\n" \
            "try [ESC] + [letter]. Example: [ESC] + [H] for [ALT] + [H].\n" \
            "[ESC] + [TAB] is also a substitute for [ALT] + [TAB].</p>"
        ) +
        # NCurses Control Center help 7/10
        _(
          "<p>3) <i>Function Keys</i><br>\n" \
            "F keys provide a quick access to main functions. " \
            "The function key bindings for the current dialog are " \
            "shown in the bottom line.</p>"
        ) +
        # NCurses Control Center help 8/10
        _("<p>The F keys are usually connected to a certain action:</p>") +
        # NCurses Control Center help 9/10
        _(
          "F1  = Help<br>\n" \
            "F2  = Info or Description<br>\n" \
            "F3  = Add<br>\n" \
            "F4  = Edit or Configure<br>\n" \
            "F5  = Delete<br>\n" \
            "F6  = Test<br>\n" \
            "F7  = Expert or Advanced<br>\n" \
            "F8  = Back<br>\n" \
            "F9  = Abort or Cancel<br>\n" \
            "F10 = OK, Next, Finish, or Accept<br>"
        ) +
        # NCurses Control Center help 10/10
        _("<p>In some environments, all or some\nF keys are not available.</p>")

      Popup.LongText(headline, RichText(help), 60, 20)

      nil
    end

    def ReplaceModuleList(group)
      # y2debug too costly: y2debug("group=%1", group);
      UI.ReplaceWidget(
        Id(:progs_rep),
        SelectionBox(
          Id(:progs),
          Opt(:notify, :keyEvents),
          "",
          Ops.get(@modules, group, [])
        )
      )

      nil
    end
  end
end

Yast::MenuClient.new.main
