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
# Module:		SignatureCheckDialogs.ycp
# Authors:		Lukas Ocilka <locilka@suse.cz>
#
# Dialogs handling for RPM/Repository GPM signatures.
#
# $Id: SignatureCheckDialogs.ycp 28363 2006-02-24 12:27:15Z locilka $
require "yast"

module Yast
  class SignatureCheckDialogsClass < Module
    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "base"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Message"
      Yast.import "DontShowAgain"
      Yast.import "Stage"
      Yast.import "Linuxrc"

      # --------------------------- Don't show this dialog again Magic ---------------------------

      # /etc/sysconfig/security:CHECK_SIGNATURES

      @check_signatures = nil # lazy

      # Standard text strings

      # GnuPG fingerprint used as "Fingerprint: AAA BBB CCC"
      @s_fingerprint = _("Fingerprint")
      # GnuPG key ID used as "Key ID: 1144AAAA444"
      @s_keyid = _("Key ID")

      # Defining icons for dialogs
      @msg_icons = {
        "error"    => "/usr/share/YaST2/theme/current/icons/32x32/apps/msg_error.png",
        "warning"  => "/usr/share/YaST2/theme/current/icons/32x32/apps/msg_warning.png",
        "question" => "/usr/share/YaST2/theme/current/icons/32x32/apps/msg_warning.png"
      }

      # UI can show images
      @has_local_image_support = nil

      # List of trusted keys
      #
      # @see bugzilla #282254
      @list_of_trusted_keys = []
    end

    # --------------------------- Don't show this dialog again Magic ---------------------------

    # Functions sets whether user want's to show the dialog again
    #
    # @param [String] popup_type dialog type
    # @param boolean show again
    # @param [String] popup_url
    def SetShowThisPopup(popup_type, show_it, popup_url)
      if popup_type.nil? || show_it.nil?
        Builtins.y2error(
          "Neither popup_type %1 nor show_it %2 can be nil!",
          popup_type,
          show_it
        )
        return
      end

      # it's the default
      if show_it
        Builtins.y2debug(
          "User decision to show dialog '%1' again is '%2'",
          popup_type,
          show_it
        )
        # store only "don't show"
      else
        Builtins.y2milestone(
          "User decision to show dialog '%1' for '%2' again is '%3'",
          popup_type,
          popup_url,
          show_it
        )
        # Show again -> false, so, store it
        DontShowAgain.SetShowQuestionAgain(
          {
            "q_type"  => "inst-source",
            "q_ident" => popup_type,
            "q_url"   => popup_url
          },
          show_it
        )
      end

      nil
    end

    # Function returns whether user want's to show the dialog (again).
    # true is the default if nothing is set.
    #
    # @param [String] popup_type dialog type
    # @param [String] popup_url if any
    # @return [Boolean] show the dialog
    def GetShowThisPopup(popup_type, popup_url)
      if popup_type.nil?
        Builtins.y2error("popup_type %1 mustn't be nil!", popup_type)
        return true
      end

      # Read the current configuration from system configuration
      stored = DontShowAgain.GetShowQuestionAgain(

        "q_type"  => "inst-source",
        "q_ident" => popup_type,
        "q_url"   => popup_url

      )

      # Stored in the configuration
      if !stored.nil?
        return stored
      else
        # Unknown status, return default
        return true
      end
    end

    # Function sets the default dialog return value
    # for case when user selected "don't show again"
    #
    # @param [String] popup_type dialog type
    # @param [Boolean] default_return
    def SetDefaultDialogReturn(popup_type, default_return, popup_url)
      if popup_type.nil? || default_return.nil?
        Builtins.y2error(
          "Neither popup_type %1 nor default_return %2 can be nil!",
          popup_type,
          default_return
        )
        return
      end
      Builtins.y2milestone(
        "User decision in default return for '%1' for '%2' is '%3'",
        popup_type,
        popup_url,
        default_return
      )
      DontShowAgain.SetDefaultReturn(
        {
          "q_type"  => "inst-source",
          "q_ident" => popup_type,
          "q_url"   => popup_url
        },
        default_return
      )

      nil
    end

    # Function returns the default popup return value
    # for case when user selected "don't show again"
    #
    # @param [String] popup_type dialog type
    # @boolean boolean default dialog return
    def GetDefaultDialogReturn(popup_type, popup_url)
      if popup_type.nil?
        Builtins.y2error("popup_type %1 mustn't be nil!", popup_type)
        return false
      end

      stored_return = Convert.to_boolean(
        DontShowAgain.GetDefaultReturn(

          "q_type"  => "inst-source",
          "q_ident" => popup_type,
          "q_url"   => popup_url

        )
      )

      Builtins.y2milestone(
        "User decided not to show popup for '%1' again, returning user-decision '%2'",
        popup_type,
        stored_return
      )
      stored_return
    end

    def HandleDoNotShowDialogAgain(default_return, dont_show_dialog_ident, dont_show_dialog_checkboxid, dont_show_url)
      dont_show_status = Convert.to_boolean(
        UI.QueryWidget(Id(dont_show_dialog_checkboxid), :Value)
      )
      # Widget doesn't exist
      if dont_show_status.nil?
        Builtins.y2warning(
          "No such UI widget with ID: %1",
          dont_show_dialog_checkboxid
        )
        # Checkbox selected -> Don't show again
      elsif dont_show_status == true
        Builtins.y2debug(
          "User decision -- don't show the dialog %1 again, setting default return %2",
          dont_show_dialog_ident,
          default_return
        )
        SetShowThisPopup(dont_show_dialog_ident, false, dont_show_url)
        SetDefaultDialogReturn(
          dont_show_dialog_ident,
          default_return,
          dont_show_url
        )
        # Checkbox not selected -> Show again
      else
        SetShowThisPopup(dont_show_dialog_ident, true, dont_show_url)
      end

      nil
    end

    # A semi-public helper. Convert the kernel parameter
    # to the sysconfig string
    # @return sysconfig value: yes, yast, no
    def CheckSignatures
      cmdline = Linuxrc.InstallInf("Cmdline")
      Builtins.y2milestone("Cmdline: %1", cmdline)

      val = Builtins.regexpsub(
        cmdline,
        "CHECK_SIGNATURES=([[:alpha:]]+)",
        "\\1"
      )
      if val.nil?
        val = Builtins.regexpsub(cmdline, "no_sig_check=([^[:digit:]]+)", "\\1")
        if !val.nil?
          trans = { "0" => "yes", "1" => "yast", "2" => "no" }
          val = Ops.get(trans, val)
        end
      end
      val = "yes" if val.nil?
      val
    end

    # Should signatures be checked at all? Check a sysconfig variable
    # (or a kernel parameter for the 1st installation stage).
    # @return do checking?
    def CheckSignaturesInYaST
      if @check_signatures.nil?
        chs = if Stage.initial
          CheckSignatures()
        else
          # default is "yes"
          Convert.to_string(
            SCR.Read(path(".sysconfig.security.CHECK_SIGNATURES"))
          )
        end
        Builtins.y2milestone("CHECK_SIGNATURES: %1", chs)
        @check_signatures = chs != "no"
      end
      @check_signatures
    end

    # Function adds delimiter between after_chars characters in the string
    #
    # @param string to be splitted
    # @param [String] delimiter
    # @param integer after characters
    # @return [String] with delimiters
    def StringSplitter(whattosplit, delimiter, after_chars)
      splittedstring = ""
      after_chars_counter = 0
      max_size = Builtins.size(whattosplit)

      loop do
        if Ops.greater_or_equal(
          Ops.add(after_chars_counter, after_chars),
          max_size
        )
          splittedstring = Ops.add(
            Ops.add(splittedstring, splittedstring == "" ? "" : delimiter),
            Builtins.substring(whattosplit, after_chars_counter)
          )
          break
        else
          splittedstring = Ops.add(
            Ops.add(splittedstring, splittedstring == "" ? "" : delimiter),
            Builtins.substring(whattosplit, after_chars_counter, after_chars)
          )
          after_chars_counter = Ops.add(after_chars_counter, after_chars)
        end
      end

      splittedstring
    end

    # Returns term with message icon
    #
    # @param string message type "error", "warning" or "question"
    # @return [Yast::Term] `Image(...) with margins
    def MessageIcon(msg_type)
      # lazy loading
      if @has_local_image_support.nil?
        ui_capabilities = UI.GetDisplayInfo
        @has_local_image_support = Ops.get_boolean(
          ui_capabilities,
          "HasLocalImageSupport",
          false
        )
      end

      # UI can show images
      if @has_local_image_support
        if Ops.get(@msg_icons, msg_type).nil?
          Builtins.y2warning("Message type %1 not defined", msg_type)
          return Empty()
        end
        return MarginBox(
          1,
          0.5,
          Image(Ops.get(@msg_icons, msg_type, ""), "[!]")
        )
      else
        return Empty()
      end
    end

    # Returns term of yes/no buttons
    #
    # @param symbol default button `yes or `no
    # @return [Yast::Term] with buttons
    def YesNoButtons(default_button)
      yes_button = PushButton(
        Id(:yes),
        Opt(:okButton, :key_F10),
        Label.YesButton
      )
      no_button = PushButton(
        Id(:no),
        Opt(:cancelButton, :key_F9),
        Label.NoButton
      )

      if default_button == :yes
        yes_button = PushButton(
          Id(:yes),
          Opt(:default, :okButton, :key_F10),
          Label.YesButton
        )
      else
        no_button = PushButton(
          Id(:no),
          Opt(:default, :cancelButton, :key_F9),
          Label.NoButton
        )
      end

      ButtonBox(yes_button, no_button)
    end

    # Returns 'true' (yes), 'false' (no) or 'nil' (cancel)
    #
    # @return [Boolean] user input yes==true
    def WaitForYesNoCancelUserInput
      user_input = nil
      ret = nil

      loop do
        user_input = UI.UserInput
        # yes button
        if user_input == :yes
          ret = true
          break
          # no button
        elsif user_input == :no
          ret = false
          break
          # closing window uisng [x]
        elsif user_input == :cancel
          ret = nil
          break
        else
          Builtins.y2error("Unknown user input: '%1'", user_input)
          next
        end
      end

      ret
    end

    # Waits for user input and checks it agains accepted symbols.
    # Returns the default symbol in case of `cancel (user closes the dialog).
    #
    # @param list <symbol> of accepted symbol by UserInput
    # @param symbol default return for case of `cancel
    def WaitForSymbolUserInput(list_of_accepted, default_symb)
      list_of_accepted = deep_copy(list_of_accepted)
      user_input = nil
      ret = nil

      loop do
        user_input = Convert.to_symbol(UI.UserInput)
        if Builtins.contains(list_of_accepted, user_input)
          ret = user_input
          break
        elsif user_input == :cancel
          ret = default_symb
          break
        else
          Builtins.y2error("Unknown user input: '%1'", user_input)
          next
        end
      end

      ret
    end

    # Used for unsiged file or package. Opens dialog asking whether user wants
    # to use this unsigned item.
    #
    # @param [Symbol] item_type `file or `package
    # @param [String] item_name file name or package name
    # @param [String] dont_show_dialog_ident for the identification in magic "don't show" functions
    # @return [Boolean] use or don't use ('true' if 'yes')
    def UseUnsignedItem(item_type, item_name, dont_show_dialog_ident, repository)
      Builtins.y2milestone(
        "UseUnsignedItem: type: %1, name: %2, dontshowid: %3, repo: %4",
        item_type,
        item_name,
        dont_show_dialog_ident,
        repository
      )

      repo = Pkg.SourceGeneralData(repository)

      description_text = Builtins.sformat(
        if item_type == :package
          # popup question, %1 stands for the package name
          # %2 is a repository name
          # %3 is URL of the repository
          _(
            "The package %1 from repository %2\n" \
              "%3\n" \
              "is not digitally signed. This means that the origin\n" \
              "and integrity of the package cannot be verified. Installing the package\n" \
              "may put the integrity of your system at risk.\n" \
              "\n" \
              "Install it anyway?"
          )
        else
          # popup question, %1 stands for the filename
          # %2 is a repository name
          # %3 is URL of the repository
          _(
            "The file %1 from repository %2\n" \
              "%3\n" \
              "is not digitally signed. The origin and integrity of the file\n" \
              "cannot be verified. Using the file anyway puts the integrity of your \n" \
              "system at risk.\n" \
              "\n" \
              "Use it anyway?\n"
          )
        end,
        item_name,
        Ops.get_locale(repo, "name", _("Unknown")),
        Ops.get_locale(repo, "url", _("Unknown"))
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HBox(
            VCenter(MessageIcon("warning")),
            # popup heading
            VCenter(
              Heading(
                if item_type == :package
                  _("Unsigned Package")
                else
                  _("Unsigned File")
                end
              )
            ),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          Left(
            MarginBox(
              0,
              1.2,
              CheckBox(
                Id(:dont_show_again),
                Message.DoNotShowMessageAgain,
                GetShowThisPopup(dont_show_dialog_ident, item_name) ? false : true
              )
            )
          ),
          YesNoButtons(:no)
        )
      )

      ret = WaitForYesNoCancelUserInput()
      # default value
      ret = false if ret.nil?

      # Store the don't show value, store the default return value
      HandleDoNotShowDialogAgain(
        ret,
        dont_show_dialog_ident,
        :dont_show_again,
        item_name
      )

      UI.CloseDialog
      ret
    end

    # Used for file or package on signed repository but without any checksum.
    # Opens dialog asking whether user wants to use this item.
    #
    # @param [Symbol] item_type `file or `package
    # @param [String] item_name file name or package name
    # @param [String] dont_show_dialog_ident for the identification in magic "don't show" functions
    # @return [Boolean] use or don't use ('true' if 'yes')
    def UseItemWithNoChecksum(item_type, item_name, dont_show_dialog_ident)
      description_text = Builtins.sformat(
        if item_type == :package
          # popup question, %1 stands for the package name
          _(
            "No checksum for package %1 was found in the repository.\n" \
              "While the package is part of the signed repository, it is not contained \n" \
              "in the list of checksums in this repository. Installing the package puts \n" \
              "the integrity of your system at risk.\n" \
              "\n" \
              "Install it anyway?\n"
          )
        else
          # popup question, %1 stands for the filename
          _(
            "No checksum for file %1 was found in the repository.\n" \
              "This means that the file is part of the signed repository,\n" \
              "but the list of checksums in this repository does not mention this file. Using the file\n" \
              "may put the integrity of your system at risk.\n" \
              "\n" \
              "Use it anyway?"
          )
        end,
        item_name
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HBox(
            VCenter(MessageIcon("warning")),
            # popup heading
            VCenter(Heading(_("No Checksum Found"))),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          Left(
            MarginBox(
              0,
              1.2,
              CheckBox(
                Id(:dont_show_again),
                Message.DoNotShowMessageAgain,
                GetShowThisPopup(dont_show_dialog_ident, item_name) ? false : true
              )
            )
          ),
          YesNoButtons(:no)
        )
      )

      ret = WaitForYesNoCancelUserInput()
      # default value
      ret = false if ret.nil?

      # Store the don't show value, store the default return value
      HandleDoNotShowDialogAgain(
        ret,
        dont_show_dialog_ident,
        :dont_show_again,
        item_name
      )

      UI.CloseDialog
      ret
    end

    def GPGKeyAsString(key)
      key = deep_copy(key)
      # Part of the GnuPG key description in popup, %1 is a GnuPG key ID
      Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Builtins.sformat(_("ID: %1"), Ops.get_string(key, "id", "")),
                "\n"
              ),
              if Ops.get_string(key, "fingerprint", "").nil? ||
                Ops.get_string(key, "fingerprint", "") == ""
                # Part of the GnuPG key description in popup, %1 is a GnuPG key fingerprint
                ""
              else
                Builtins.sformat(
                  _("Fingerprint: %1") + "\n",
                  StringSplitter(Ops.get_string(key, "fingerprint", ""), " ", 4)
                )
              end
            ),
            # Part of the GnuPG key description in popup, %1 is a GnuPG key name
            Builtins.sformat(_("Name: %1"), Ops.get_string(key, "name", ""))
          ),
          if Ops.get_string(key, "created", "") != ""
            Ops.add(
              "\n",
              Builtins.sformat(
                _("Created: %1"),
                Ops.get_string(key, "created", "")
              )
            )
          else
            ""
          end
        ),
        if Ops.get_string(key, "expires", "") != ""
          Ops.add(
            "\n",
            Builtins.sformat(
              _("Expires: %1"),
              Ops.get_string(key, "expires", "")
            )
          )
        else
          ""
        end
      )
    end

    def GPGKeyAsTerm(key)
      key = deep_copy(key)
      rt = Ops.add(
        # GPG key property
        Builtins.sformat(
          "<b>%1</b>%2",
          _("ID: "),
          Ops.get_string(key, "id", "")
        ),
        # GPG key property
        Builtins.sformat(
          "<br><b>%1</b>%2",
          _("Name: "),
          Ops.get_string(key, "name", "")
        )
      )
      if Ops.greater_than(
        Builtins.size(Ops.get_string(key, "fingerprint", "")),
        0
      )
        # GPG key property
        rt = Ops.add(
          rt,
          Builtins.sformat(
            "<br><b>%1</b>%2",
            _("Fingerprint: "),
            StringSplitter(Ops.get_string(key, "fingerprint", ""), " ", 4)
          )
        )
      end
      if Ops.greater_than(Builtins.size(Ops.get_string(key, "created", "")), 0)
        # GPG key property
        rt = Ops.add(
          rt,
          Builtins.sformat(
            "<br><b>%1</b>%2",
            _("Created: "),
            Ops.get_string(key, "created", "")
          )
        )
      end
      if Ops.greater_than(Builtins.size(Ops.get_string(key, "expires", "")), 0)
        # GPG key property
        rt = Ops.add(
          rt,
          Builtins.sformat(
            "<br><b>%1</b>%2",
            _("Expires: "),
            Ops.get_string(key, "expires", "")
          )
        )
      end
      RichText(rt)
    end

    # Used for corrupted file or package. Opens dialog asking whether user wants
    # to use this corrupted item.
    #
    # @param [Symbol] item_type `file or `package
    # @param [String] item_name file name or package name
    # @param [Hash{String => Object}] key Used key
    # @return [Boolean] use or don't use ('true' if 'yes')
    def UseCorruptedItem(item_type, item_name, key, repository)
      key = deep_copy(key)
      repo = Pkg.SourceGeneralData(repository)

      description_text = Builtins.sformat(
        if item_type == :package
          # popup question, %1 stands for the package name, %2 for the complete description of the GnuPG key (multiline)
          _(
            "Package %1 from repository %2\n" \
              "%3\n" \
              "is signed with the following GnuPG key, but the integrity check failed: %4\n" \
              "\n" \
              "The package has been changed, either by accident or by an attacker,\n" \
              "since the repository creator signed it. Installing it is a big risk\n" \
              "for the integrity and security of your system.\n" \
              "\n" \
              "Install it anyway?\n"
          )
        else
          # popup question, %1 stands for the filename, %2 for the complete description of the GnuPG key (multiline)
          _(
            "File %1 from repository %2\n" \
              "%3\n" \
              "is signed with the following GnuPG key, but the integrity check failed: %4\n" \
              "\n" \
              "The file has been changed, either by accident or by an attacker,\n" \
              "since the repository creator signed it. Using it is a big risk\n" \
              "for the integrity and security of your system.\n" \
              "\n" \
              "Use it anyway?\n"
          )
        end,
        item_name,
        Ops.get_locale(repo, "name", _("Unknown")),
        Ops.get_locale(repo, "url", _("Unknown")),
        Ops.add("\n\n", GPGKeyAsString(key))
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          # popup heading
          HBox(
            VCenter(MessageIcon("error")),
            VCenter(Heading(_("Validation Check Failed"))),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          YesNoButtons(:no)
        )
      )

      ret = WaitForYesNoCancelUserInput()
      # default value
      ret = false if ret.nil?

      UI.CloseDialog
      ret
    end

    # Used for file or package signed by unknown key.
    #
    # @param [Symbol] item_type `file or `package
    # @param [String] item_name file name or package name
    # @param [String] key_id
    # @param string fingerprint
    # @param [String] dont_show_dialog_ident for the identification in magic "don't show" functions
    # @param [Fixnum] repoid Id of the repository from the item was downloaded
    # @return [Boolean] true if 'yes, use file'
    def ItemSignedWithUnknownSignature(item_type, item_name, key_id, dont_show_dialog_ident, repoid)
      repo_url = Ops.get_string(Pkg.SourceGeneralData(repoid), "url", "")
      description_text = Builtins.sformat(
        if item_type == :package
          # popup question, %1 stands for the package name, %2 for the complex multiline description of the GnuPG key
          _(
            "The package %1 is digitally signed\n" \
              "with the following unknown GnuPG key: %2.\n" \
              "\n" \
              "This means that a trust relationship to the creator of the package\n" \
              "cannot be established. Installing the package may put the integrity\n" \
              "of your system at risk.\n" \
              "\n" \
              "Install it anyway?"
          )
        else
          # popup question, %1 stands for the filename, %2 for the complex multiline description of the GnuPG key
          _(
            "The file %1\n" \
              "is digitally signed with the following unknown GnuPG key: %2.\n" \
              "\n" \
              "This means that a trust relationship to the creator of the file\n" \
              "cannot be established. Using the file may put the integrity\n" \
              "of your system at risk.\n" \
              "\n" \
              "Use it anyway?"
          )
        end,
        # TODO: use something like "%1 from %2" and make it translatable
        if repo_url != ""
          Builtins.sformat("%1 (%2)", item_name, repo_url)
        else
          item_name
        end,
        Ops.add(
          "\n",
          # Part of the GnuPG key description in popup, %1 is a GnuPG key ID
          Builtins.sformat(_("ID: %1"), key_id)
        )
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HBox(
            VCenter(MessageIcon("warning")),
            # popup heading
            VCenter(Heading(_("Unknown GnuPG Key"))),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          Left(
            MarginBox(
              0,
              1.2,
              CheckBox(
                Id(:dont_show_again),
                Message.DoNotShowMessageAgain,
                GetShowThisPopup(dont_show_dialog_ident, item_name) ? false : true
              )
            )
          ),
          YesNoButtons(:no)
        )
      )

      # This will optionally offer to retrieve the key from gpg keyservers
      # That's why it will return 'symbol' instead of 'boolean'
      # But by now it only handles yes/no/cancel
      ret = WaitForYesNoCancelUserInput()
      # default value
      ret = false if ret.nil?

      # Store the don't show value, store the default return value
      HandleDoNotShowDialogAgain(
        ret,
        dont_show_dialog_ident,
        :dont_show_again,
        item_name
      )

      UI.CloseDialog
      ret
    end

    # Used for file or package signed by a public key. This key is still
    # not listed in trusted keys.
    #
    # @param [Symbol] item_type `file or `package
    # @param [String] item_name file name or package name
    # @param string key_id
    # @param string key_name
    # @return [Symbol] `key_import, `install, `skip
    def ItemSignedWithPublicSignature(item_type, item_name, key)
      key = deep_copy(key)
      description_text = Builtins.sformat(
        if item_type == :package
          # popup question, %1 stands for the package name, %2 for the key ID, %3 for the key name
          _(
            "The package %1 is digitally signed\n" \
              "with key '%2 (%3)'.\n" \
              "\n" \
              "There is no trust relationship with the owner of the key.\n" \
              "If you trust the owner, mark the key as trusted.\n" \
              "\n" \
              "Installing a package from an unknown repository puts\n" \
              "the integrity of your system at risk. It is safest\n" \
              "to skip the package.\n"
          )
        else
          # popup question, %1 stands for the filename, %2 for the key ID, %3 for the key name
          _(
            "The file %1 is digitally signed\n" \
              "with key '%2 (%3)'.\n" \
              "\n" \
              "There is no trust relationship with the owner of the key.\n" \
              "If you trust the owner, mark the key as trusted.\n" \
              "\n" \
              "Installing a file from an unknown repository puts\n" \
              "the integrity of your system at risk. It is safest\n" \
              "to skip it.\n"
          )
        end,
        item_name,
        Ops.get_string(key, "id", ""),
        Ops.get_string(key, "name", "")
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HBox(
            VCenter(MessageIcon("warning")),
            # popup heading
            VCenter(Heading(_("Signed with Untrusted Public Key"))),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          ButtonBox(
            # push button
            PushButton(
              Id(:trust),
              Opt(:okButton, :key_F10),
              _("&Trust and Import the Key")
            ),
            PushButton(Id(:skip), Opt(:cancelButton, :key_F9), Label.SkipButton)
          )
        )
      )
      UI.SetFocus(:skip)

      # wait for one of listed ID's, return the default value in case of `cancel
      ret = WaitForSymbolUserInput([:trust, :skip], :skip)

      if ret == :trust
        # later, if asking whether to import the key, the key is trusted
        # so it will be also imported
        # bugzilla #282254
        @list_of_trusted_keys = Builtins.add(
          @list_of_trusted_keys,
          Ops.get_string(key, "id", "")
        )
      end

      UI.CloseDialog
      ret
    end

    # ImportUntrustedGPGKeyIntoTrustedDialog
    #
    # @param string key_id
    # @param string key_name
    # @param string fingerprint
    # @return [Boolean] whether zypp should import the key into the keyring of trusted keys
    def ImportGPGKeyIntoTrustedDialog(key, repository)
      key = deep_copy(key)
      # additional Richtext (HTML) warning text (kind of help), 1/2
      warning_text = _(
        "<p>The owner of the key may distribute updates,\n" \
          "packages, and package repositories that your system will trust and offer\n" \
          "for installation and update without any further warning. In this way,\n" \
          "importing the key into your keyring of trusted keys allows the key owner\n" \
          "to have a certain amount of control over the software on your system.</p>"
      ) +
        # additional Richtext (HTML) warning text (kind of help), 2/2
        _(
          "<p>A warning dialog opens for every package that\n" \
            "is not signed by a trusted (imported) key. If you do not trust the key,\n" \
            "the packages or repositories created by the owner of the key will not be used.</p>"
        )

      repo = Pkg.SourceGeneralData(repository)

      # popup message - label, part 1, %1 stands for repository name, %2 for its URL
      dialog_text = Builtins.sformat(
        _(
          "The following GnuPG key has been found in repository\n" \
            "%1\n" \
            "(%2):"
        ),
        Ops.get_locale(repo, "name", _("Unknown")),
        repo && repo["url"] ? repo["url"].scan(/.{1,59}/).join("\n") :
          _("Unknown")
      )

      # popup message - label, part 2
      dialog_text2 = _(
        "You can choose to import it into your keyring of trusted\n" \
          "public keys, meaning that you trust the owner of the key.\n" \
          "You should be sure that you can trust the owner and that\n" \
          "the key really belongs to that owner before importing it."
      )

      expires = Ops.get_integer(key, "expires_raw", 0)
      if Ops.greater_than(expires, 0) &&
          Ops.greater_than(Builtins.time, expires)
        # warning label - the key to import is expired
        dialog_text2 = Ops.add(
          Ops.add(Builtins.sformat(_("WARNING: The key has expired!")), "\n\n"),
          dialog_text2
        )
      end

      displayinfo = UI.GetDisplayInfo
      # hide additional help text in not enough wide terminals so
      # the important GPG key properties are completely displayed
      hide_help = Ops.get_boolean(displayinfo, "TextMode", false) &&
        Ops.less_than(Ops.get_integer(displayinfo, "Width", 80), 105)

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          # left-side help
          if hide_help
            Empty()
          else
            HWeight(3, VBox(RichText(warning_text)))
          end,
          HSpacing(1.5),
          # dialog
          HWeight(
            5,
            VBox(
              HBox(
                VCenter(MessageIcon("question")),
                # popup heading
                VCenter(Heading(_("Import Untrusted GnuPG Key"))),
                HStretch()
              ),
              # dialog message
              MarginBox(
                0.4,
                0.4,
                VBox(
                  Left(Label(dialog_text)),
                  GPGKeyAsTerm(key),
                  Left(Label(dialog_text2))
                )
              ),
              # dialog buttons
              ButtonBox(
                # push button
                PushButton(Id(:trust), Opt(:key_F10, :okButton), _("&Trust")),
                PushButton(
                  Id(:cancel),
                  Opt(:key_F9, :cancelButton),
                  Label.CancelButton
                )
              )
            )
          )
        )
      )

      UI.SetFocus(:cancel)

      ret = Convert.to_symbol(UI.UserInput)

      UI.CloseDialog

      ret == :trust
    end

    def RunSimpleErrorPopup(heading, description_text, dont_show_dialog_ident, dont_show_dialog_param)
      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          # popup heading
          HBox(
            VCenter(MessageIcon("error")),
            # dialog heading - displayed in a big bold font
            VCenter(Heading(heading)),
            HStretch()
          ),
          MarginBox(0.5, 0.5, Label(description_text)),
          Left(
            MarginBox(
              0,
              1.2,
              CheckBox(
                Id(:dont_show_again),
                Message.DoNotShowMessageAgain,
                GetShowThisPopup(dont_show_dialog_ident, dont_show_dialog_param) ? false : true
              )
            )
          ),
          YesNoButtons(:no)
        )
      )

      ret = WaitForYesNoCancelUserInput()
      # default value
      ret = false if ret.nil?

      # Store the don't show value, store the default return value
      HandleDoNotShowDialogAgain(
        ret,
        dont_show_dialog_ident,
        :dont_show_again,
        dont_show_dialog_param
      )

      UI.CloseDialog

      ret
    end

    # Ask user to accept wrong digest
    # @param [String] filename Name of the file
    # @param [String] requested_digest Expected checksum
    # @param [String] found_digest Current checksum
    # @param [String] dont_show_dialog_ident Uniq ID for "don't show again"
    # @return [Boolean] true when user accepts the file
    def UseFileWithWrongDigest(filename, requested_digest, found_digest, dont_show_dialog_ident)
      description_text =
        # popup question, %1 stands for the filename, %2 is expected checksum
        # %3 is the current checksum (e.g. "803a8ff00d00c9075a1bd223a480bcf92d2481c1")
        Builtins.sformat(
          _(
            "The expected checksum of file %1\n" \
              "is %2,\n" \
              "but the current checksum is %3.\n" \
              "\n" \
              "The file has been changed by accident or by an attacker\n" \
              "since the repository creator signed it. Using it is a big risk\n" \
              "for the integrity and security of your system.\n" \
              "\n" \
              "Use it anyway?\n"
          ),
          filename,
          requested_digest,
          found_digest
        )

      # dialog heading - displayed in a big bold font
      heading = _("Wrong Digest")

      RunSimpleErrorPopup(
        heading,
        description_text,
        dont_show_dialog_ident,
        filename
      )
    end

    # Ask user to accept a file with unknown checksum
    # @param [String] filename Name of the file
    # @param [String] digest Current checksum
    # @param [String] dont_show_dialog_ident Uniq ID for "don't show again"
    # @return [Boolean] true when user accepts the file
    def UseFileWithUnknownDigest(filename, digest, dont_show_dialog_ident)
      description_text =
        # popup question, %1 stands for the filename, %2 is expected digest, %3 is the current digest
        Builtins.sformat(
          _(
            "The checksum of file %1\n" \
              "is %2,\n" \
              "but the expected checksum is not known.\n" \
              "\n" \
              "This means that the origin and integrity of the file\n" \
              "cannot be verified. Using the file puts the integrity of your system at risk.\n" \
              "\n" \
              "Use it anyway?\n"
          ),
          filename,
          digest
        )
      # dialog heading - displayed in a big bold font
      heading = _("Unknown Digest")

      RunSimpleErrorPopup(
        heading,
        description_text,
        dont_show_dialog_ident,
        filename
      )
    end

    publish function: :SetShowThisPopup, type: "void (string, boolean, string)"
    publish function: :GetShowThisPopup, type: "boolean (string, string)"
    publish function: :SetDefaultDialogReturn, type: "void (string, boolean, string)"
    publish function: :GetDefaultDialogReturn, type: "boolean (string, string)"
    publish function: :CheckSignatures, type: "string ()"
    publish function: :CheckSignaturesInYaST, type: "boolean ()"
    publish function: :UseUnsignedItem, type: "boolean (symbol, string, string, integer)"
    publish function: :UseItemWithNoChecksum, type: "boolean (symbol, string, string)"
    publish function: :UseCorruptedItem, type: "boolean (symbol, string, map <string, any>, integer)"
    publish function: :ItemSignedWithUnknownSignature, type: "boolean (symbol, string, string, string, integer)"
    publish function: :ItemSignedWithPublicSignature, type: "symbol (symbol, string, map <string, any>)"
    publish function: :ImportGPGKeyIntoTrustedDialog, type: "boolean (map <string, any>, integer)"
    publish function: :UseFileWithWrongDigest, type: "boolean (string, string, string, string)"
    publish function: :UseFileWithUnknownDigest, type: "boolean (string, string, string)"
  end

  SignatureCheckDialogs = SignatureCheckDialogsClass.new
  SignatureCheckDialogs.main
end
