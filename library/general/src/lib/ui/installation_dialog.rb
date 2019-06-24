# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "ui/dialog"

module UI
  # Subclass of UI::Dialog to be used by installation steps.
  #
  # When used in YaST normal mode, it opens a one-step wizard to allow manual
  # testing of the dialog
  #
  # @example simple dialog to set a setting
  #   Yast.import "Bar"
  #   class FooDialog < UI::InstallationDialog
  #     def initialize
  #       super
  #       textdomain "example"
  #     end
  #
  #     def dialog_content
  #       InputField(Id(:foo), "Value for Foo", Yast::Bar.foo)
  #     end
  #
  #     def dialog_title
  #       "Foo"
  #     end
  #
  #     def help_text
  #       "<p>Set the value for foo here.</p>
  #     end
  #
  #     def next_handler
  #       Yast::Bar.foo = Yast::UI.QueryWidget(Id(:foo), :Value)
  #       super
  #     end
  #   end
  #
  #   # In the installation client
  #   FooDialog.run
  #
  class InstallationDialog < Dialog
    def initialize
      super
      Yast.import "Mode"
      Yast.import "Wizard"
      Yast.import "GetInstArgs"
      Yast.import "Popup"
      @_wizard_opened = false
    end

    # Handler for the 'accept' event
    #
    # Used when the dialog is called from a proposal, by default it simply calls
    # the handler for 'next'
    def accept_handler
      next_handler
    end

    # Handler for the 'next' event
    def next_handler
      finish_dialog(:next)
    end

    # Handler for the 'back' event
    def back_handler
      finish_dialog(:back)
    end

    # Handler for the 'cancel' event
    def cancel_handler
      finish_dialog(:cancel)
    end

    # Handler for the 'abort' event
    #
    # The default implementation ask the user for confirmation
    def abort_handler
      finish_dialog(:abort) if Yast::Popup.ConfirmAbort(:painless)
    end

  protected

    # Optional title icon
    #
    # @return [String] name of the icon to use
    def title_icon
    end

    # Headline for the dialog
    #
    # @return [String]
    def dialog_title
      ""
    end

    # Text to display when the help button is pressed
    #
    # @return [String]
    def help_text
      ""
    end

    # Reimplementation of UI::Dialog#create_dialog for the installer
    #
    # It ignores UI::Dialog#dialog_options
    def create_dialog
      if dialog_options
        log.info "This is an InstallationDialog, ignoring #dialog_options"
      end

      # Allow manual testing
      if !Yast::Wizard.IsWizardDialog
        @_wizard_opened = true
        Yast::Wizard.CreateDialog
      end

      Yast::Wizard.SetContents(
        dialog_title,
        dialog_content,
        help_text,
        Yast::GetInstArgs.enable_back,
        Yast::GetInstArgs.enable_next || Yast::Mode.normal
      )
      true
    end

    def close_dialog
      return unless @_wizard_opened

      @_wizard_opened = false
      Yast::Wizard.CloseDialog
    end
  end
end
