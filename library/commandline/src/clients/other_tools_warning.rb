# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2014 SUSE LLC
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

#*
# There may be different ways to configure the system than YaST, e.g. Chef.
# It will periodically overwrite files under its control.
# If it is running, now is a good time to tell the user
# and ask if she wants to proceed with YaST anyway.
# We do not try to find out which files these are and ask
# before any interactive YaST module.
# See bnc#803358

module Yast
  class OtherToolsWarningClient < Client
    def main
      Yast.import "Popup"
      textdomain "base"

      if WFM.Args().include? "chef"
        # Translators: a warning message in a continue-cancel question
        # Opscode Chef is a different way to configure the system.
        message = _(
           "Chef Client is running. The changes that you make\n" +
             "may be overridden by Chef later.\n" +
             "Continue configuration with YaST?"
        )
        return Popup.ContinueCancel(message)
      end

    end
  end
end

Yast::OtherToolsWarningClient.new.main
