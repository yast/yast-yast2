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
module Yast
  class WizardDialogClient < Client
    def main
      Yast.import "UI"
      # test wizard_dialog

      textdomain "wizard_testsuite"
      Yast.import "Wizard"

      Wizard.CreateDialog
      Wizard.SetHelpText(
        _("<p>This is the example of <tt>CreateWizardDialog()</tt></p>")
      )
      @ret = Wizard.UserInput
      UI.CloseDialog

      deep_copy(@ret)
    end
  end
end

Yast::WizardDialogClient.new.main
