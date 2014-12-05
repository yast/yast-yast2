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
# File:	modules/Confirm.ycp
#
# Package:	yast2
#
# Summary:	Confirmation routines
#
# Authors:	Michal Svec <msvec@suse.cz>
#
# Flags:	Stable
#
# $Id$
require "yast"

module Yast
  class ConfirmClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Icon"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Linuxrc"
      Yast.import "Stage"
      Yast.import "Arch"

      # #TODO bug number
      @detection_cache = {}
    end

    # Confirm hardware detection (only in manual installation)
    # @param [String] class hardware class (network cards)
    # @param [String] icon_name name of the icon. If nil, generic hardware icon will be used
    # @return true on continue
    def Detection(_class, icon_name)
      return true if Linuxrc.manual != true

      # L3: no interaction in AY, just re-probe (bnc#568653)
      return true if Mode.autoinst == true || Mode.autoupgrade == true

      return true if Arch.s390

      icon_name = "yast-hardware" if icon_name == nil

      icon = Icon.Image(icon_name, {})

      result = Ops.get(@detection_cache, _class)
      if result != nil
        log.info "Detection cached result: #{_class} -> #{result}"
        return result
      end

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          HCenter(
            HSquash(
              VBox(
                HCenter(
                  HSquash(
                    VBox(
                      # Popup-Box for manual hardware detection.
                      # If the user selects 'manual installation' when
                      # booting from CD, YaST2 does not load any modules
                      # automatically, but asks the user for confirmation
                      # about every module.
                      # The popup box informs the user about the detected
                      # hardware and suggests a module to load.
                      # The user can confirm the module or change
                      # the suggested load command
                      #
                      # This is the heading of the popup box
                      Left(Heading(_("Confirm Hardware Detection"))),
                      VSpacing(0.5),
                      # This is in information message. Next come the
                      # hardware class name (network cards).
                      HVCenter(
                        Label(_("YaST will detect the following hardware:"))
                      ),
                      HVCenter(HBox(icon, HSpacing(0.5), Heading(_class))),
                      VSpacing(0.5)
                    )
                  )
                ),
                ButtonBox(
                  HWeight(
                    1,
                    PushButton(
                      Id(:continue),
                      Opt(:default, :okButton),
                      Label.ContinueButton
                    )
                  ),
                  # PushButton label
                  HWeight(
                    1,
                    PushButton(Id(:skip), Opt(:cancelButton), _("&Skip"))
                  )
                ),
                VSpacing(0.2)
              )
            )
          ),
          HSpacing(1)
        )
      )

      UI.SetFocus(Id(:continue))

      # for autoinstallation popup has timeout 10 seconds (#192181)
      # timeout for every case (bnc#429562)
      ret = UI.TimeoutUserInput(10 * 1000)
      #    any ret = Mode::autoinst() ? UI::TimeoutUserInput(10*1000) : UI::UserInput();
      UI.CloseDialog

      result = true
      if ret != :continue
        log.info "Detection skipped: #{_class}"
        result = false
      end

      Ops.set(@detection_cache, _class, result)
      result
    end

    # y2milestone("--%1", Detection("graphics cards"));
    # Linuxrc::manual () = true;
    # y2milestone("--%1", Detection("network cards"));
    # y2milestone("--%1", Detection("modems"));

    # If we are running as root, return true.
    # Otherwise ask the user whether we should continue even though things
    # might not work
    # @return true if running as root
    def MustBeRoot
      if Ops.less_or_equal(
          Convert.to_integer(SCR.Read(path(".target.size"), "/usr/bin/id")),
          0
        )
        if !Stage.initial
          log.warn "/usr/bin/id not existing, supposing to be root"
        end
        return true
      end

      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/usr/bin/id --user")
      )
      root = Ops.get_string(out, "stdout", "") == "0\n"
      return true if root

      # Message in a continue/cancel popup
      pop = _(
        "This module must be run as root.\n" +
          "If you continue now, the module may not function properly.\n" +
          "For example, some settings can be read improperly\n" +
          "and it is unlikely that settings can be written.\n"
      )

      # Popup headline
      if Popup.ContinueCancelHeadline(_("Root Privileges Needed"), pop)
        log.error "NOT running as root!"
        return true
      end

      false
    end

    #  * Opens a popup yes/no confirmation.
    #
    #  * If users confirms deleting, return true,
    #  * else return false
    #  *
    #  * @return boolean delete selected entry
    def DeleteSelected
      Popup.YesNo(
        # Popup question
        _("Really delete selected entry?")
      )
    end

    #  * Opens a popup yes/no confirmation.
    #
    #  * If users confirms deleting of named entry/file/etc.,
    #  * return true, else return false
    #  *
    #  * @param string file/entry name/etc.
    #  * @return boolean delete selected entry
    def Delete(delete)
      Popup.YesNo(
        # Popup question, %1 is an item to delete (or filename, etc.)
        Builtins.sformat(_("Really delete '%1'?"), delete)
      )
    end

    publish :function => :Detection, :type => "boolean (string, string)"
    publish :function => :MustBeRoot, :type => "boolean ()"
    publish :function => :DeleteSelected, :type => "boolean ()"
    publish :function => :Delete, :type => "boolean (string)"
  end

  Confirm = ConfirmClass.new
  Confirm.main
end
