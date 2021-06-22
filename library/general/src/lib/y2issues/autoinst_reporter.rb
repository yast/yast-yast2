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

require "yast"
require "y2issues/reporter"

Yast.import "Label"
Yast.import "HTML"

module Y2Issues
  # This class provides a mechanism to report YaST2 issues at the beginning of the AutoYaST
  # installation process, before any real change has been done to the system
  #
  # In contrast to the base reporter (which only informs the user), this gives the user the
  # possibility to abort. Thus, the return value of {#report} must be checked by the caller
  # to handle that situation.
  class AutoinstReporter < Reporter
    # @see Reporter#initialize
    def initialize(*args)
      super(*args)
      textdomain "base"
    end

  private

    # Displays a pop-up containing the issues
    #
    # It can behave in two different ways depending if the issues are only
    # warnings or an error was found:
    #
    # * Ask the user if she/he wants to continue or abort the installation.
    # * Display a message and only offer an 'Abort' button.
    def show_issues
      if level == :error
        headline = :error
        buttons = { abort: Yast::Label.AbortButton }
        question = _("Please, correct these problems and try again.")
        timeout = 0
      else
        headline = :warning
        buttons = :yes_no
        question = _("Do you want to continue?")
        timeout = @timeout
      end

      content = presenter.to_html + Yast::HTML.Para(question)
      Yast2::Popup.show(
        content, richtext: true, headline: headline, buttons: buttons, timeout: timeout
      )
    end
  end
end
