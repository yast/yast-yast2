# typed: false
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "cwm/dialog"

Yast.import "Popup"

module CWM
  # CWM pop-up dialog
  #
  # This class offers a CWM dialog which behaves as a pop-up.
  # @see {CWM::Dialog} for remaining configuration options.
  class Popup < Dialog
    # Determines that a dialog should always be open
    #
    # @return [true]
    #
    # @see CWM::Dialog#wizard_create_dialog
    def should_open_dialog?
      true
    end

    # Popup does not allow nil, so overwrite Dialog default value.
    # @return [String] The dialog title.
    def title
      ""
    end

  private

    # Redefines the mechanism to open the dialog to use the adapted layout
    #
    # @param block [Proc]
    # @see CWM::Dialog#wizard_create_dialog
    def wizard_create_dialog(&block)
      Yast::UI.OpenDialog(layout)
      block.call
    ensure
      Yast::UI.CloseDialog
    end

    # Defines the dialog's layout
    #
    # @return [Yast::Term]
    def layout
      VBox(
        Id(:WizardDialog),
        HSpacing(50),
        Left(Heading(Id(:title), title)),
        VStretch(),
        VSpacing(1),
        MinSize(min_width, min_height, ReplacePoint(Id(:contents), Empty())),
        VSpacing(1),
        VStretch(),
        ButtonBox(*buttons)
      )
    end

    # Popup min width
    #
    # @return [Integer]
    def min_width
      1
    end

    # Popup min height
    #
    # @return [Integer]
    def min_height
      1
    end

    def ok_button_label
      Yast::Label.OKButton
    end

    def cancel_button_label
      Yast::Label.CancelButton
    end

    def buttons
      [help_button, ok_button, cancel_button]
    end

    def help_button
      PushButton(Id(:help), Opt(:helpButton), Yast::Label.HelpButton)
    end

    def ok_button
      PushButton(Id(:ok), Opt(:default), ok_button_label)
    end

    def cancel_button
      PushButton(Id(:cancel), cancel_button_label)
    end
  end
end
