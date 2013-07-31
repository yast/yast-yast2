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
# File:	modules/Message.ycp
# Package:	yast2
# Summary:	Often used messages
# Authors:	Lukas Ocilka <locilka@suse.cz>
# Copyright:   Copyright 2004, Novell, Inc.  All rights reserved.
# Flags:	Stable
#
# $Id$
#
# Often used messages, for example error messages
require "yast"

module Yast
  class MessageClass < Module
    def main
      textdomain "base"
    end

    # Cannot continue without required packages installed
    # @return [String] Cannot continue without required packages installed
    def CannotContinueWithoutPackagesInstalled
      # TRANSLATORS: Popup message
      _(
        "YaST cannot continue the configuration\nwithout installing the required packages."
      )
    end

    # Cannot start 'service_name' service
    # @param [String] service_name
    # @return [String] Cannot start 'service_name' service
    def CannotStartService(service_name)
      # TRANSLATORS: Popup message, %1 is a service name like "smbd"
      Builtins.sformat(_("Cannot start '%1' service"), service_name)
    end

    # Cannot restart 'service_name' service
    # @param [String] service_name
    # @return [String] Cannot restart 'service_name' service
    def CannotRestartService(service_name)
      # TRANSLATORS: Popup message, %1 is a service name like "smbd"
      Builtins.sformat(_("Cannot restart '%1' service"), service_name)
    end

    # Cannot stop 'service_name' service
    # @param [String] service_name
    # @return [String] Cannot stop 'service_name' service
    def CannotStopService(service_name)
      # TRANSLATORS: Popup message, %1 is a service name like "smbd"
      Builtins.sformat(_("Cannot stop '%1' service"), service_name)
    end

    # Cannot write settings to 'destination'
    # @param [String] destination
    # @return [String] Cannot write settings to 'destination'
    def CannotWriteSettingsTo(destination)
      # TRANSLATORS: Popup message, %1 is file or service name like "/tmp/out" or "LDAP"
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(_("Cannot write settings to '%1'"), destination)
    end

    # Cannot write settings to 'destination'\n\nReason: reason
    # @param [String] destination
    # @param [String] reason
    # @return [String] Cannot write settings to 'destination'\n\nReason: reason
    def CannotWriteSettingsToBecause(destination, reason)
      # TRANSLATORS: Popup message, %1 is file or service name like "/tmp/out" or "LDAP", %2 is the reason of error
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(
        _(
          "Cannot write settings to '%1'.\n" +
            "\n" +
            "Reason: %2"
        ),
        destination,
        reason
      )
    end

    # Error writing file 'file'
    # @param [String] file
    # @return [String] Error writing file 'file'
    def ErrorWritingFile(file)
      # TRANSLATORS: Popup message, %1 is a file name like "/tmp/out"
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(_("Error writing file '%1'"), file)
    end

    # Error writing file 'file'\n\nReason: reason
    # @param [String] file
    # @param [String] reason
    # @return [String] Error writing file 'file'\n\nReason: reason
    def ErrorWritingFileBecause(file, reason)
      # TRANSLATORS: Popup message, %1 is a file name like "/tmp/out", %2 is the reason of error
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(
        _("Error writing file '%1'.\n\nReason: %2"),
        file,
        reason
      )
    end

    # Cannot open file 'file'
    # @param [String] file
    # @return [String] Cannot open file 'file'
    def CannotOpenFile(file)
      # TRANSLATORS: Popup message, %1 is the name of file like "/tmp/in"
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(_("Cannot open file '%1'"), file)
    end

    # Cannot open file 'file'\n\nReason: reason
    # @param [String] file
    # @param [String] reason
    # @return [String] Cannot open file 'file'\n\nReason: reason
    def CannotOpenFileBecause(file, reason)
      # TRANSLATORS: Popup message, %1 is the name of file like "/tmp/in", %2 is the reason of error
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English filename
      #  (see BNC #584466 for details)
      Builtins.sformat(_("Cannot open file '%1'.\n\nReason: %2"), file, reason)
    end

    # Finished
    # @return [String] Finished
    def Finished
      # TRANSLATORS: Progress stage text
      _("Finished")
    end

    # Check the environment
    # @return [String] Check the environment
    def CheckEnvironment
      # TRANSLATORS: Progress stage text
      _("Check the environment")
    end

    # UnknownError\n\nReason: reason
    # @param [String] reason
    # @return [String] UnknownError\n\nReason: reason
    def UnknownError(reason)
      # TRANSLATORS: Popup message, %1 is the description of error
      Builtins.sformat(_("Unknown Error.\n\nDescription: %1"), reason)
    end

    # Required text item
    # @return This item is required to be filled in
    def RequiredItem
      # TRANSLATORS: Popup message
      _("This item must be completed.")
    end

    # Question: Directory does not exist. Create it?
    # @return [String] The directory '%1' does not exist.\nCreate it?
    def DirectoryDoesNotExistCreate(directory)
      # TRANSLATORS: Popup question
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English directory
      #  (see BNC #584466 for details)
      Builtins.sformat(
        _("The directory '%1' does not exist.\nCreate it?"),
        directory
      )
    end

    # Domain has changed, you have to reboot now for domain
    # to take effect
    # @return The domain has changed.\nYou must reboot for the changes to take effect.
    def DomainHasChangedMustReboot
      # TRANSLATORS: Popup message
      _(
        "The domain has changed.\nYou must reboot for the changes to take effect."
      )
    end

    # Push Button / CheckBox for not to disturb with this message again
    # @return [String] Do Not Show This Message &Again
    def DoNotShowMessageAgain
      # TRANSLATORS: CheckBox / Button
      _("Do Not Show This Message &Again")
    end

    # Cannot ajust 'service_name' service
    # @param [String] service_name
    # @return [String] Cannot adjust 'service_name' service
    def CannotAdjustService(service_name)
      # TRANSLATORS: Popup message, %1 is a service name like "smbd"
      Builtins.sformat(_("Cannot adjust '%1' service."), service_name)
    end

    # When some parameter is missing
    # @param [String] parameter
    # @return [String] Missing parameter '%1'.
    def MissingParameter(parameter)
      # TRANSLATORS: Popup message, %1 is a missing-parameter name
      Builtins.sformat(_("Missing parameter '%1'."), parameter)
    end

    # When is is not able to create directory
    # @param [String] directory
    # @return [String] Unable to create directory '%1'.
    def UnableToCreateDirectory(directory)
      # TRANSLATORS: Popup message, %1 is a directory name
      #  For Right-To-Left languages, you want to put %1 into its own empty line so
      #  the text renderer doesn't get trip with the English directory
      #  (see BNC #584466 for details)
      Builtins.sformat(_("Cannot create directory '%1'."), directory)
    end

    # When is is not able to read current settings
    # @return [String] Cannot read current settings.
    def CannotReadCurrentSettings
      # TRANSLATORS: Popup message
      _("Cannot read current settings.")
    end

    # Running SuSEConfig failed
    # @return [String] SuSEconfig script failed.
    def SuSEConfigFailed
      # TRANSLATORS: Popup message
      _("SuSEconfig script failed.")
    end

    # Installing packages failed
    # @return [String] Failed to install required packages.
    def FailedToInstallPackages
      # TRANSLATORS: Popup message
      _("Failed to install required packages.")
    end

    publish :function => :CannotContinueWithoutPackagesInstalled, :type => "string ()"
    publish :function => :CannotStartService, :type => "string (string)"
    publish :function => :CannotRestartService, :type => "string (string)"
    publish :function => :CannotStopService, :type => "string (string)"
    publish :function => :CannotWriteSettingsTo, :type => "string (string)"
    publish :function => :CannotWriteSettingsToBecause, :type => "string (string, string)"
    publish :function => :ErrorWritingFile, :type => "string (string)"
    publish :function => :ErrorWritingFileBecause, :type => "string (string, string)"
    publish :function => :CannotOpenFile, :type => "string (string)"
    publish :function => :CannotOpenFileBecause, :type => "string (string, string)"
    publish :function => :Finished, :type => "string ()"
    publish :function => :CheckEnvironment, :type => "string ()"
    publish :function => :UnknownError, :type => "string (string)"
    publish :function => :RequiredItem, :type => "string ()"
    publish :function => :DirectoryDoesNotExistCreate, :type => "string (string)"
    publish :function => :DomainHasChangedMustReboot, :type => "string ()"
    publish :function => :DoNotShowMessageAgain, :type => "string ()"
    publish :function => :CannotAdjustService, :type => "string (string)"
    publish :function => :MissingParameter, :type => "string (string)"
    publish :function => :UnableToCreateDirectory, :type => "string (string)"
    publish :function => :CannotReadCurrentSettings, :type => "string ()"
    publish :function => :SuSEConfigFailed, :type => "string ()"
    publish :function => :FailedToInstallPackages, :type => "string ()"
  end

  Message = MessageClass.new
  Message.main
end
