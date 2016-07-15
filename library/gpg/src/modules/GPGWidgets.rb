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
# File:	modules/GPGWidgets.ycp
# Package:	yast2
# Summary:	UI widgets and functions related to GPG
# Authors:	Ladislav Slezák <lslezak@suse.cz>
#
# $Id$
#
# This module provides UI related functions to GPG.
require "yast"

module Yast
  class GPGWidgetsClass < Module
    def main
      Yast.import "UI"

      Yast.import "Mode"
      Yast.import "GPG"
      Yast.import "Label"
      Yast.import "CWM"
      Yast.import "CommandLine"

      textdomain "base"

      # the selected private key in the private key table
      @_selected_id_private_key = nil
      # the selected public key in the public key table
      @_selected_id_public_key = nil

      # Passphrase entered in the passphrase widget
      @passphrase = ""
    end

    # Set selected private key in the private key table widget.
    # @param [String] keyid ID of the selected key
    def SetSelectedPrivateKey(keyid)
      @_selected_id_private_key = keyid

      nil
    end

    # Set selected public key in the public key table widget.
    # @param [String] keyid ID of the selected key
    def SetSelectedPublicKey(keyid)
      @_selected_id_public_key = keyid

      nil
    end

    # Get list of table items for CWM widget.
    # @param [Boolean] private_keys if true use private keys, otherwise use public keys
    # @return [Array<Yast::Term>] list of items
    def GPGItems(private_keys)
      ret = []
      keys = private_keys ? GPG.PrivateKeys : GPG.PublicKeys

      Builtins.foreach(keys) do |key|
        uids = Builtins.mergestring(Ops.get_list(key, "uid", []), ", ")
        ret = Builtins.add(
          ret,
          Item(
            Id(Ops.get_string(key, "id", "")),
            Ops.get_string(key, "id", ""),
            uids,
            Ops.get_string(key, "fingerprint", "")
          )
        )
      end

      deep_copy(ret)
    end

    # Init function of a widget - initialize the private table widget
    # @param [String] key string widget key
    def GpgInitPrivate(key)
      Builtins.y2milestone("GpgInitPrivate: %1", key)

      if key == "select_private_key"
        UI.ChangeWidget(Id(:gpg_priv_table), :Items, GPGItems(true))

        if !@_selected_id_private_key.nil?
          UI.ChangeWidget(
            Id(:gpg_priv_table),
            :CurrentItem,
            @_selected_id_private_key
          )
        end
      end

      nil
    end

    # Init function of a widget - initialize the public table widget
    # @param [String] key string widget key
    def GpgInitPublic(key)
      Builtins.y2milestone("GpgInitPublic: %1", key)

      if key == "select_public_key"
        UI.ChangeWidget(Id(:gpg_public_table), :Items, GPGItems(false))

        if !@_selected_id_public_key.nil?
          UI.ChangeWidget(
            Id(:gpg_public_table),
            :CurrentItem,
            @_selected_id_public_key
          )
        end
      end

      nil
    end

    # Store the selected private key
    # @param [String] key widget ID
    # @param [Hash] event event
    def GpgStorePrivate(key, event)
      event = deep_copy(event)
      Builtins.y2debug("GpgStorePrivate: %1, %2", key, event)

      if key == "select_private_key"
        @_selected_id_private_key = Convert.to_string(
          UI.QueryWidget(Id(:gpg_priv_table), :CurrentItem)
        )
        Builtins.y2milestone(
          "Selected private key: %1",
          @_selected_id_private_key
        )
      end

      nil
    end

    # Store the selected public key
    # @param [String] key widget ID
    # @param [Hash] event event
    def GpgStorePublic(key, event)
      event = deep_copy(event)
      Builtins.y2debug("GpgStorePublic: %1, %2", key, event)

      if key == "select_public_key"
        @_selected_id_public_key = Convert.to_string(
          UI.QueryWidget(Id(:gpg_public_table), :CurrentItem)
        )
        Builtins.y2milestone(
          "Selected public key: %1",
          @_selected_id_public_key
        )
      end

      nil
    end

    # Return the selected private key in the private table widget
    # @return [String] key ID
    def SelectedPrivateKey
      @_selected_id_private_key
    end

    # Get widget description map
    # @return widget description map
    def PrivateKeySelection
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Left(Label(Id(:gpg_priv_label), _("GPG Private Keys"))),
          Table(
            Id(:gpg_priv_table),
            # table header - GPG key ID
            Header(
              _("Key ID"),
              # table header - GPG key user ID
              _("User ID"),
              # table header - GPG key fingerprint
              _("Fingerprint")
            ),
            # fill up the widget in init handler
            []
          )
        ),
        "init"          => fun_ref(method(:GpgInitPrivate), "void (string)"),
        "store"         => fun_ref(
          method(:GpgStorePrivate),
          "void (string, map)"
        ),
        "help"          => _(
          "<p><big><b>GPG Private Key</b></big><br>\nThe table contains list of the private GPG keys.</p>"
        )
      }
    end

    # Get widget description map
    # @return widget description map
    def PublicKeySelection
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Left(Label(_("GPG Public Keys"))),
          Table(
            Id(:gpg_public_table),
            # table header - GPG key ID
            Header(
              _("Key ID"),
              # table header - GPG key user ID
              _("User ID"),
              # table header - GPG key fingerprint
              _("Fingerprint")
            ),
            # fill up the widget in init handler
            []
          )
        ),
        "init"          => fun_ref(method(:GpgInitPublic), "void (string)"),
        "store"         => fun_ref(
          method(:GpgStorePublic),
          "void (string, map)"
        ),
        "help"          => _(
          "<p><big><b>GPG Public Key</b></big><br>\nThe table contains list of the public GPG keys.</p>"
        )
      }
    end

    # Refresh the widgets after creating a new gpg key
    # @param [String] key widget ID
    # @param [Hash] event event
    def GpgNewKey(key, event)
      event = deep_copy(event)
      Builtins.y2debug("GpgNewKey: %1, %2", key, event)

      if key == "create_new_key"
        GPG.CreateKey

        # refresh private key widget if it's existing
        if UI.WidgetExists(Id(:gpg_priv_table))
          current = Convert.to_string(
            UI.QueryWidget(Id(:gpg_priv_table), :CurrentItem)
          )
          UI.ChangeWidget(Id(:gpg_priv_table), :Items, GPGItems(true))
          UI.ChangeWidget(Id(:gpg_priv_table), :CurrentItem, current)
        end

        # refresh public key widget if it's existing
        if UI.WidgetExists(Id(:gpg_public_table))
          current = Convert.to_string(
            UI.QueryWidget(Id(:gpg_public_table), :CurrentItem)
          )
          UI.ChangeWidget(Id(:gpg_public_table), :Items, GPGItems(false))
          UI.ChangeWidget(Id(:gpg_public_table), :CurrentItem, current)
        end
      end

      nil
    end

    # Get widget description map
    # @return widget description map
    def CreateNewKey
      {
        "widget"        => :push_button,
        "label"         => _("&Create a new GPG key..."),
        "handle_events" => ["create_new_key"],
        "handle"        => fun_ref(method(:GpgNewKey), "symbol (string, map)"),
        "help"          => _(
          "<p><big><b>Create a new GPG key</b></big><br>\n" \
            "<tt>gpg --gen-key</tt> is started, see <tt>gpg</tt> manual pager for more information.\n" \
            "Press Ctrl+C to cancel.\n" \
            "</p>"
        )
      }
    end

    # Store the passphrase from the widget
    # @param [String] key widget ID
    # @param [Hash] event event
    def PassphraseStore(key, event)
      event = deep_copy(event)
      Builtins.y2debug("PassphraseStore: %1, %2", key, event)

      if Ops.get_symbol(event, "WidgetID", :_none) == :ok
        @passphrase = Convert.to_string(UI.QueryWidget(Id(:passphrase), :Value))
      end

      nil
    end

    # Get the enterd passphrase.
    # @return passphrase
    def Passphrase
      @passphrase
    end

    # Return definition of the passphrase CWM widget.
    # @param [String] key key ID displayed in the label
    # @return [Hash{String => map<String,Object>}] widget definition
    def AskPassphraseWidget(key)
      {
        "ask_passphrase" => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            # text entry
            Password(
              Id(:passphrase),
              Builtins.sformat(_("&Passphrase for GPG Key %1"), key)
            )
          ),
          "store"         => fun_ref(
            method(:PassphraseStore),
            "void (string, map)"
          ),
          # help text
          "help"          => _(
            "<p><big><b>Passphrase</b></big><br>\nEnter passphrase to unlock the GPG key."
          )
        }
      }
    end

    # Create a popup window term with the passphrase widget.
    # @return [Yast::Term] definition of the popup
    def AskPassphraseTerm
      MarginBox(
        term(:leftMargin, 1),
        term(:rightMargin, 1),
        term(:topMargin, 0.2),
        term(:bottomMargin, 0.5),
        VBox(
          HSpacing(50),
          Heading(_("Enter Passphrase")),
          "ask_passphrase",
          VSpacing(0.5),
          ButtonBox(
            PushButton(
              Id(:ok),
              Opt(:default, :okButton, :key_F10),
              Label.OKButton
            ),
            PushButton(
              Id(:cancel),
              Opt(:cancelButton, :key_F9),
              Label.CancelButton
            )
          )
        )
      )
    end

    # Ask user to enter the passphrase for the selected gpg key.
    # A a popup window is displayed.
    # @param [String] key key ID of the gpg key
    # @return [String] the entered passphrase or nil if the popup has been closed by [Cancel] button
    def AskPassphrasePopup(key)
      @passphrase = nil

      if Mode.commandline
        # no input possible
        return nil unless CommandLine.Interactive

        # ask for the passphrase in the commandline (interactive) mode
        return CommandLine.PasswordInput(
          Builtins.sformat(_("Enter Passphrase to Unlock GPG Key %1: "), key)
        )
      end

      # run the dialog
      w = CWM.CreateWidgets(["ask_passphrase"], AskPassphraseWidget(key))

      contents = AskPassphraseTerm()
      contents = CWM.PrepareDialog(contents, w)

      UI.OpenDialog(contents)
      UI.SetFocus(Id(:passphrase))
      CWM.Run(w, {})
      UI.CloseDialog

      @passphrase
    end

    # Return a map with CWM widgets definition. The map contains definitions of all static CWM widgets.
    # @return [Hash{String,map<String => Object>}] CWM widgets
    def Widgets
      {
        "select_private_key" => PrivateKeySelection(),
        "select_public_key"  => PublicKeySelection(),
        "create_new_key"     => CreateNewKey()
      }
    end

    publish function: :SetSelectedPrivateKey, type: "void (string)"
    publish function: :SetSelectedPublicKey, type: "void (string)"
    publish function: :SelectedPrivateKey, type: "string ()"
    publish function: :Passphrase, type: "string ()"
    publish function: :AskPassphraseWidget, type: "map <string, map <string, any>> (string)"
    publish function: :AskPassphrasePopup, type: "string (string)"
    publish function: :Widgets, type: "map <string, map <string, any>> ()"
  end

  GPGWidgets = GPGWidgetsClass.new
  GPGWidgets.main
end
