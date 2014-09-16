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
# Module:		PackageCallbacks.ycp
#
# Authors:		Gabriele Strattner <gs@suse.de>
#			Klaus Kaempf <kkaempf@suse.de>
#			Arvin Schnell <arvin@suse.de>
#
# Purpose:		provides the default Callbacks for Pkg::
#
# $Id$
#
require "yast"
require "uri"

module Yast
  class PackageCallbacksClass < Module
    include Yast::Logger

    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "base"

      Yast.import "Installation"
      Yast.import "Directory"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Popup"
      Yast.import "URL"
      Yast.import "CommandLine"
      Yast.import "String"
      Yast.import "Report"
      Yast.import "Icon"
      Yast.import "Wizard"
      Yast.import "Progress"
      Yast.import "FileUtils"
      Yast.import "SignatureCheckCallbacks"

      @_provide_popup = false
      @_source_popup = false
      @_package_popup = false
      @_script_popup = false
      @_scan_popup = false
      @_package_name = ""
      @_package_size = 0
      @_deleting_package = false

      @_current_source = 1

      # make showLongInfo module-global so it gets remembered (cf. #14018)
      @showLongInfo = false


      # used to en-/disable StartPackage, ProgressPackage and DonePackage
      @enable_asterix_package = true

      @provide_aborted = false
      @source_aborted = false

      @back_string = ""
      @clear_string = Ops.add(Ops.add(@back_string, "          "), @back_string)

      # max. length of the text in the repository popup window
      @max_size = 60

      @autorefreshing = false
      @autorefreshing_aborted = false

      # Location of the persistent storage
      @conf_file = Ops.add(Directory.vardir, "/package_callbacks.conf")
      @config = nil

      # auto ejecting is in progress
      @doing_eject = false

      # seconds for automatic retry after a timeout
      @retry_timeout = 30
      # number of automatic retries
      @retry_attempts = 100
      # max. retry timeout (15 minutes)
      @retry_max_timeout = 15 * 60

      # current values for retry functionality
      @retry_url = ""
      @current_retry_timeout = @retry_timeout
      @current_retry_attempt = 0

      @vsize_no_details = 1


      #=============================================================================
      #	MEDIA CHANGE
      #=============================================================================

      @detected_cd_devices = []

      # reference couter to the open popup window
      @_source_open = 0

      @download_file = ""

      # TODO: use the ID in the prgress popup callbacks,
      # then callbacks may be nested...

      @tick_labels = ["/", "-", "\\", "|"]
      @tick_progress = false
      @val_progress = false
      @current_tick = 0
      @progress_task = ""

      # ProgressStart/End events may be nested, remember the types of progresses
      @progress_stack = []


      @last_stage = 0

      @opened_wizard = []
      PackageCallbacks()
    end

    def textmode
      Mode.commandline ?
        true :
        Ops.get_boolean(UI.GetDisplayInfo, "TextMode", false)
    end

    def display_width
      Mode.commandline ? 0 : Ops.get_integer(UI.GetDisplayInfo, "Width", 0)
    end

    # functions related to the persistent storage
    def LoadConfig
      if FileUtils.Exists(@conf_file) && FileUtils.IsFile(@conf_file)
        Builtins.y2milestone("Reading config file %1", @conf_file)
        read_conf = Convert.to_map(SCR.Read(path(".target.ycp"), @conf_file))

        @config = read_conf != nil ? read_conf : {}
        Builtins.y2milestone("Current config: %1", @config)
      else
        Builtins.y2milestone(
          "No configuration found (file %1 is missing)",
          @conf_file
        )
      end

      @config = {} if @config == nil

      nil
    end

    def GetConfig(key)
      LoadConfig() if @config == nil

      Ops.get(@config, key)
    end

    def SetConfig(key, value)
      value = deep_copy(value)
      LoadConfig() if @config == nil

      Builtins.y2milestone("Config: setting %1 to %2", key, value)
      Ops.set(@config, key, value)

      nil
    end

    def SaveConfig
      Builtins.y2milestone("Saving the current config to %1", @conf_file)
      SCR.Write(path(".target.ycp"), @conf_file, @config)
    end

    #--------------------------------------------------------------------------
    # defaults

    def ProgressBox(heading, name, sz)
      progressbox = VBox(
        HSpacing(40),
        # popup heading
        Heading(heading),
        Left(
          HBox(
            VBox(
              Left(Label(Opt(:boldFont), _("Package: "))),
              Left(Label(Opt(:boldFont), _("Size: ")))
            ),
            VBox(Left(Label(name)), Left(Label(sz)))
          )
        ),
        ProgressBar(Id(:progress), " ", 100, 0),
        ButtonBox(
          PushButton(Id(:abort), Opt(:key_F9, :cancelButton), Label.AbortButton)
        )
      )
      deep_copy(progressbox)
    end

    def FullScreen
      return false if Mode.commandline

      ret = UI.WidgetExists(:progress_replace_point)
      Builtins.y2debug("Running in fullscreen mode: %1", ret)
      ret
    end

    def RetryLabel(timeout)
      Builtins.sformat(
        _("Remaining time to automatic retry: %1"),
        String.FormatTime(timeout)
      )
    end

    # at start of file providal
    #
    def StartProvide(name, archivesize, remote)
      Builtins.y2milestone("StartProvide: name: %1, remote: %2", name, remote)
      if remote
        sz = String.FormatSizeWithPrecision(archivesize, 2, false)
        if Mode.commandline
          CommandLine.PrintVerbose(
            Builtins.sformat(_("Downloading package %1 (%2)..."), name, sz)
          )
        else
          UI.CloseDialog if @_provide_popup

          if FullScreen()
            Progress.SubprogressType(:progress, 100)
            Progress.SubprogressTitle(
              Builtins.sformat(_("Downloading package %1 (%2)..."), name, sz)
            )
          else
            # popup heading
            providebox = ProgressBox(_("Downloading Package"), name, sz)
            UI.OpenDialog(providebox)
            @_provide_popup = true
          end
        end
      end

      nil
    end



    # during file providal
    #
    def ProgressProvide(percent)
      Builtins.y2milestone("ProgressProvide: %1", percent)
      if @_provide_popup
        UI.ChangeWidget(Id(:progress), :Value, percent)
        @provide_aborted = UI.PollInput == :abort
        return !@provide_aborted
      elsif Mode.commandline
        # there is no popup window, but command line mode is set
        CommandLine.PrintVerboseNoCR(
          Ops.add(@clear_string, Builtins.sformat("%1%%", percent))
        )
      end
      true
    end

    # redirect ProgressDeltaApply callback (a different signature is required)
    def ProgressDeltaApply(percent)
      ProgressProvide(percent)

      nil
    end



    # creates layout for ChangeMediumPopup
    def LayoutPopup(message, button_box, vertical_size, info_on)
      button_box = deep_copy(button_box)
      dialog_layout = VBox(
        HSpacing(50), # enforce width
        VSpacing(0.1),
        HBox(
          # maybe more icon types could be used
          # "info, "warning", "error"
          Icon.Image("warning", { "margin_right" => 2 }),
          Left(Label(message))
        ),
        VSpacing(0.1),
        HBox(
          HSpacing(0.6),
          Left(
            CheckBox(
              Id(:show),
              Opt(:notify),
              # check box
              _("Show &details"),
              info_on
            )
          )
        ),
        VSpacing(0.4),
        HBox(
          VSpacing(vertical_size),
          HSpacing(0.1),
          ReplacePoint(Id(:info), Empty()),
          HSpacing(0.1)
        ),
        HBox(HSpacing(0.1), button_box, HSpacing(0.1)),
        VSpacing(0.2)
      )
      deep_copy(dialog_layout)
    end

    def ShowLogInfo(message, buttonbox)
      buttonbox = deep_copy(buttonbox)
      if UI.QueryWidget(Id(:show), :Value) == true
        UI.CloseDialog
        UI.OpenDialog(
          Opt(:decorated),
          LayoutPopup(message, buttonbox, 10, true)
        )
        return true
      else
        UI.CloseDialog
        UI.OpenDialog(
          Opt(:decorated),
          LayoutPopup(message, buttonbox, @vsize_no_details, false)
        )
        UI.ReplaceWidget(Id(:info), Empty())
      end
      false
    end


    # during file providal
    #  *
    #  // return "I" for ignore
    #  // return "R" for retry
    #  // return "C" for abort
    def DoneProvide(error, reason, name)
      Builtins.y2milestone("DoneProvide: %1, %2, %3", error, reason, name)

      if @_provide_popup
        UI.CloseDialog
        @_provide_popup = false
      end

      if Mode.commandline
        # remove the progress
        CommandLine.PrintVerboseNoCR(@clear_string)
      end

      if @provide_aborted
        @provide_aborted = false
        return "C"
      end

      # INVALID
      if error == 3
        # error message, %1 is a package name
        message = Builtins.sformat(
          _("Package %1 is broken, integrity check has failed."),
          name
        )


        if Mode.commandline
          CommandLine.Print(message)

          # ask user in the interactive mode
          if CommandLine.Interactive
            CommandLine.Print("")

            # command line mode - ask user whether installation of the failed package should be retried
            CommandLine.Print(_("Retry installation of the package?"))

            if CommandLine.YesNo
              # return Retry
              return "R"
            end

            # command line mode - ask user whether the installation should be aborted
            CommandLine.Print(_("Abort the installation?"))
            if CommandLine.YesNo
              # return Abort
              return "C"
            end

            # otherwise return Ignore (default)
            return "I"
          end

          return "I"
        end

        button_box = ButtonBox(
          PushButton(Id(:abort), Opt(:cancelButton, :key_F9), Label.AbortButton),
          PushButton(Id(:retry), Opt(:customButton), Label.RetryButton),
          PushButton(Id(:ignore), Opt(:okButton), Label.SkipButton)
        )

        if @showLongInfo
          UI.OpenDialog(
            Opt(:decorated),
            LayoutPopup(message, button_box, 10, true)
          )
          UI.ReplaceWidget(
            Id(:info),
            RichText(
              Opt(:plainText),
              Ops.add(Builtins.sformat(_("Error: %1:"), error), reason)
            )
          )
        else
          UI.OpenDialog(
            Opt(:decorated),
            LayoutPopup(message, button_box, @vsize_no_details, false)
          )
          UI.ReplaceWidget(Id(:info), Empty())
        end

        r = nil
        begin
          r = UI.UserInput
          if r == :show
            @showLongInfo = ShowLogInfo(message, button_box)
            if @showLongInfo
              error_symbol = "ERROR"

              if error == 1
                error_symbol = "NOT_FOUND"
              elsif error == 2
                error_symbol = "IO"
              elsif error == 3
                error_symbol = "INVALID"
              end

              UI.ReplaceWidget(
                Id(:info),
                RichText(
                  Opt(:plainText),
                  Ops.add(
                    # error message, %1 is code of the error,
                    # detail string is appended to the end
                    Builtins.sformat(_("Error: %1:"), error_symbol),
                    reason
                  )
                )
              )
            else
              UI.ReplaceWidget(Id(:info), Empty())
            end
          end
        end until r == :abort || r == :retry || r == :ignore

        Builtins.y2milestone("DoneProvide %1", r)

        UI.CloseDialog

        return "C" if r == :abort
        return "R" if r == :retry
        if r == :ignore
          # don't show the warning when a refresh fails
          if !@autorefreshing
            # TODO: add "Don't show again" checkbox
            # a warning popup displayed after pressing [Ignore] after a download error
            Popup.Warning(
              _(
                "Ignoring a download failure may result in a broken system.\nVerify the system later by running the Software Management module.\n"
              )
            )
          end

          return "I"
        end

        Builtins.y2error("Unknown user input: %1", r)
      end

      "I"
    end


    #  Enable or disable StartPackage, ProgressPackage and DonePackage
    #  callbacks, but only the progress bar and not the final error
    #  message.  Returns old value.
    def EnableAsterixPackage(f)
      ret = @enable_asterix_package
      @enable_asterix_package = f
      ret
    end



    #  At start of package install.
    def StartPackage(name, location, summary, installsize, is_delete)
      return if !@enable_asterix_package

      @_package_name = name
      @_package_size = installsize
      @_deleting_package = is_delete
      sz = String.FormatSizeWithPrecision(installsize, 2, false)

      if Mode.commandline
        CommandLine.PrintVerbose(
          Builtins.sformat(
            is_delete ?
              _("Uninstalling package %1 (%2)...") :
              _("Installing package %1 (%2)..."),
            @_package_name,
            sz
          )
        )
      else
        packagebox = ProgressBox(
          is_delete ? _("Uninstalling Package") : _("Installing Package"),
          @_package_name,
          sz
        )

        UI.OpenDialog(Opt(:decorated), packagebox)
        @_package_popup = true
      end

      nil
    end


    #  During package install.
    def ProgressPackage(percent)
      if @_package_popup
        UI.ChangeWidget(Id(:progress), :Value, percent)
        return UI.PollInput != :abort
      elsif Mode.commandline
        CommandLine.PrintVerboseNoCR(
          Ops.add(@clear_string, Builtins.sformat("%1%%", percent))
        )
        if percent == 100
          # sleep for a wile
          Builtins.sleep(200)
          # remove the progress
          CommandLine.PrintVerboseNoCR(@clear_string)
        end
      end

      true
    end


    #  After package install.
    #
    #  return "I" for ignore
    #  return "R" for retry
    #  return "C" for abort (not implemented !)
    def DonePackage(error, reason)

      # remove invalid characters (bnc#876459)
      if !reason.valid_encoding?
        reason.encode!('UTF-16', :undef => :replace, :invalid => :replace, :replace => "?")
        reason.encode!('UTF-8')
        log.warn "Invalid byte sequence found, fixed text: #{reason}"
      end

      UI.CloseDialog if @_package_popup
      @_package_popup = false

      if error != 0
        Builtins.y2milestone(
          "DonePackage(error: %1, reason: '%2')",
          error,
          reason
        )

        message = Builtins.sformat(
          @_deleting_package ?
            # error popup during package installation, %1 is the name of the package
            _("Removal of package %1 failed.") :
            # error popup during package installation, %1 is the name of the package
            _("Installation of package %1 failed."),
          @_package_name
        )

        if Mode.commandline
          CommandLine.Print(message)
          CommandLine.Print(reason)

          # ask user in the interactive mode
          if CommandLine.Interactive
            CommandLine.Print("")

            # command line mode - ask user whether installation of the failed package should be retried
            CommandLine.Print(_("Retry installation of the package?"))

            if CommandLine.YesNo
              # return Retry
              return "R"
            end

            # command line mode - ask user whether the installation should be aborted
            CommandLine.Print(_("Abort the installation?"))
            if CommandLine.YesNo
              # return Abort
              return "C"
            end

            # otherwise return Ignore (default)
            return "I"
          end
        else
          button_box = ButtonBox(
            PushButton(Id(:abort), Opt(:cancelButton), Label.AbortButton),
            PushButton(Id(:retry), Opt(:customButton), Label.RetryButton),
            PushButton(Id(:ignore), Opt(:okButton), Label.IgnoreButton)
          )

          if @showLongInfo
            UI.OpenDialog(
              Opt(:decorated),
              LayoutPopup(message, button_box, 10, true)
            )
            UI.ReplaceWidget(Id(:info), RichText(Opt(:plainText), reason))
          else
            UI.OpenDialog(
              Opt(:decorated),
              LayoutPopup(message, button_box, @vsize_no_details, false)
            )
            UI.ReplaceWidget(Id(:info), Empty())
          end

          r = nil
          begin
            r = UI.UserInput
            if r == :show
              @showLongInfo = ShowLogInfo(message, button_box)
              if @showLongInfo
                UI.ReplaceWidget(Id(:info), RichText(Opt(:plainText), reason))
              else
                UI.ReplaceWidget(Id(:info), Empty())
              end
            end
          end until r == :abort || r == :retry || r == :ignore

          Builtins.y2milestone("DonePackage %1", r)

          UI.CloseDialog

          if r == :ignore
            # TODO: add "Don't show again" checkbox
            # a warning popup displayed after pressing [Ignore] after a package installation error
            Popup.Warning(
              _(
                "Ignoring a package failure may result in a broken system.\nThe system should be later verified by running the Software Management module."
              )
            )
          end

          return "C" if r == :abort
          return "R" if r == :retry
        end 

        # default: ignore
      else
        # no error, there is additional info (rpm output), see bnc#456446
        Builtins.y2milestone("Additional RPM otput: %1", reason)

        CommandLine.Print(reason) if Mode.commandline
      end

      "I"
    end

    def CDdevices(preferred)
      cds = Convert.convert(
        SCR.Read(path(".probe.cdrom")),
        :from => "any",
        :to   => "list <map>"
      )
      ret = []

      Builtins.foreach(cds) do |cd|
        dev = Ops.get_string(cd, "dev_name", "")
        model = Ops.get_string(cd, "model", "")
        deflt = preferred == dev
        if dev != nil && dev != "" && model != nil
          ret = Builtins.add(
            ret,
            Item(
              Id(dev),
              Ops.add(
                Ops.add(deflt ? "\u27A4 " : "", model),
                Builtins.sformat(" (%1)", dev)
              )
            )
          )
        end
      end if cds != nil

      Builtins.y2milestone("Detected CD devices: %1", ret)

      deep_copy(ret)
    end

    # check and save the autoeject configuration if needed
    def CheckAndSaveAutoEject
      autoeject = Convert.to_boolean(UI.QueryWidget(Id(:auto_eject), :Value))

      current = Convert.to_boolean(GetConfig("automatic_eject"))
      current = false if current == nil

      if autoeject != current
        SetConfig("automatic_eject", autoeject)
        SaveConfig()
      end

      nil
    end




    #-------------------------------------------------------------------------
    #
    # media change callback
    #
    # if current == -1, show "Ignore"
    #
    # return "" for ok, retry
    # return "E" for eject media
    # return "I" for ignore bad media
    # return "S" for skip this media
    # return "C" for cancel (not implemented !)
    # return url to change media URL

    def MediaChange(error_code, error, url, product, current, current_label, wanted, wanted_label, double_sided, devices, current_device)
      devices = deep_copy(devices)
      if @autorefreshing && @autorefreshing_aborted
        Builtins.y2milestone("Refresh aborted")
        return "C"
      end

      Builtins.y2milestone(
        "MediaChange error: err'%1', url'%2', prd'%3', cur'%4'/'%5', wan'%6'/'%7', devs: %8, curr_dev: %9",
        Ops.add(Ops.add(error_code, ":"), error),
        URL.HidePassword(url),
        product,
        current,
        current_label,
        wanted,
        wanted_label,
        devices,
        current_device
      )

      url_tokens = URL.Parse(url)
      url_scheme = Ops.get_string(url_tokens, "scheme", "")
      url_scheme = Builtins.tolower(url_scheme)

      # true if it makes sense to offer an eject button (for cd/dvd only ...)
      offer_eject_button = url_scheme == "cd" || url_scheme == "dvd"

      # do automatic eject
      if offer_eject_button &&
          Convert.to_boolean(GetConfig("automatic_eject")) == true
        if !@doing_eject
          Builtins.y2milestone("Automatically ejecting the medium...")
          @doing_eject = true
          return "E"
        end
      end

      if Builtins.issubstring(error, "ERROR(InstSrc:E_bad_id)")
        error =
          # error report
          _(
            "<p>The repository at the specified URL now provides a different media ID.\n" +
              "If the URL is correct, this indicates that the repository content has changed. To \n" +
              "continue using this repository, start <b>Installation Repositories</b> from \n" +
              "the YaST control center and refresh the repository.</p>\n"
          )
      end

      if wanted_label == ""
        # use only product name for network repository
        # there is no medium 1, 2, ...
        if double_sided
          # media is double sided, we want the user to insert the 'Side A' of the media
          # the complete string will be "<product> <media> <number>, <side>"
          # e.g. "'SuSE Linux 9.0' DVD 1, Side A"
          side = _("Side A")
          if Ops.bitwise_and(wanted, 1) == 0
            # media is double sided, we want the user to insert the 'Side B' of the media
            side = _("Side B")
          end
          wanted = Ops.shift_right(Ops.add(wanted, 1), 1)
          wanted_label = url_scheme == "cd" || url_scheme == "dvd" ?
            # label for a repository - %1 product name (e.g. "openSUSE 10.2"), %2 medium number (e.g. 2)
            # %3 side (e.g. "Side A")
            Builtins.sformat("%1 (Disc %2, %3)", product, wanted, side) :
            # label for a repository - %1 product name (e.g. "openSUSE 10.2"), %2 medium number (e.g. 2)
            # %3 side (e.g. "Side A")
            Builtins.sformat("%1 (Medium %2, %3)", product, wanted, side)
        else
          wanted_label = Builtins.tolower(url_scheme) == "cd" ||
            Builtins.tolower(url_scheme) == "dvd" ?
            # label for a repository - %1 product name (e.g. openSUSE 10.2), %2 medium number (e.g. 2)
            Builtins.sformat(_("%1 (Disc %2)"), product, wanted) :
            # label for a repository - %1 product name (e.g. openSUSE 10.2), %2 medium number (e.g. 2)
            Builtins.sformat(_("%1 (Medium %2)"), product, wanted)
        end
      end

      # prompt to insert product (%1 == "SuSE Linux version 9.2 CD 2")
      message = Builtins.sformat(_("Insert\n'%1'"), wanted_label)
      # with network repository it doesn't make sense to ask for disk
      if url_scheme == "dir"
        # report error while accessing local directory with product (%1 = URL, %2 = "SuSE Linux ...")
        message = Builtins.sformat(
          _(
            "Cannot access installation media\n" +
              "%1\n" +
              "%2.\n" +
              "Check whether the directory is accessible."
          ),
          URL.HidePassword(url),
          wanted_label
        )
      elsif url_scheme != "cd" && url_scheme != "dvd"
        # report error while accessing network media of product (%1 = URL, %2 = "SuSE Linux ...")
        message = Builtins.sformat(
          _(
            "Cannot access installation media \n" +
              "%1\n" +
              "%2.\n" +
              "Check whether the server is accessible."
          ),
          URL.HidePassword(url),
          wanted_label
        )
      end

      # currently unused
      media_prompt = _("The correct repository medium could not be mounted.")

      # --------------------------------------
      # build up button box

      button_box = ButtonBox(
        PushButton(Id(:retry), Opt(:default, :okButton), Label.RetryButton)
      )

      if current == -1 # wrong media id, offer "Ignore"
        button_box = Builtins.add(
          button_box,
          PushButton(Id(:ignore), Opt(:customButton), Label.IgnoreButton)
        )
      end

      button_box = Builtins.add(
        button_box,
        PushButton(
          Id(:cancel),
          Opt(:cancelButton),
          @autorefreshing ? _("Skip Autorefresh") : Label.AbortButton
        )
      )

      # push button label during media change popup, user can skip
      # this media (CD) so no packages from this media will be installed
      button_box = Builtins.add(
        button_box,
        PushButton(Id(:skip), Opt(:customButton), _("&Skip"))
      )

      if offer_eject_button
        if !@doing_eject
          @detected_cd_devices = CDdevices(Ops.get(devices, current_device, ""))
        end

        # detect the CD/DVD devices if the ejecting is not in progress,
        # the CD detection closes the ejected tray!
        cds = deep_copy(@detected_cd_devices)

        # display a menu button if there are more CD devices
        if Ops.greater_than(Builtins.size(cds), 1)
          # menu button label - used for more then one device
          button_box = HBox(button_box, MenuButton(_("&Eject"), cds))
        else
          # push button label - in the media change popup, user can eject the CD/DVD
          button_box = Builtins.add(
            button_box,
            PushButton(Id(:eject), Opt(:customButton), _("&Eject"))
          )
        end


        auto_eject = Convert.to_boolean(GetConfig("automatic_eject"))
        auto_eject = false if auto_eject == nil

        button_box = VBox(
          Left(
            CheckBox(
              Id(:auto_eject),
              _("A&utomatically Eject CD or DVD Medium"),
              auto_eject
            )
          ),
          button_box
        )
      end

      @doing_eject = false

      # Autoretry code
      doing_auto_retry = false

      if error_code == "IO_SOFT" ||
          Builtins.contains(
            ["ftp", "sftp", "http", "https", "nfs", "smb"],
            url_scheme
          )
        # this a different file, reset the retry counter
        if @retry_url != url
          @retry_url = url
          @current_retry_attempt = 0
        end

        # is the maximum retry count reached?
        if Ops.less_than(@current_retry_attempt, @retry_attempts)
          # reset the counter, use logarithmic back-off with maximum limit
          @current_retry_timeout = Ops.less_than(@current_retry_attempt, 10) ?
            Ops.multiply(
              @retry_timeout,
              Ops.shift_left(1, @current_retry_attempt)
            ) :
            @retry_max_timeout

          if Ops.greater_than(@current_retry_timeout, @retry_max_timeout)
            @current_retry_timeout = @retry_max_timeout
          end

          button_box = VBox(
            # failed download will be automatically retried after the timeout, %1 = formatted time (MM:SS format)
            Left(Label(Id(:auto_retry), RetryLabel(@current_retry_timeout))),
            button_box
          )

          doing_auto_retry = true
        else
          Builtins.y2warning(
            "Max. autoretry count (%1) reached, giving up...",
            @retry_attempts
          )
        end
      end

      Builtins.y2milestone("Autoretry: %1", doing_auto_retry)

      if doing_auto_retry
        Builtins.y2milestone("Autoretry attempt: %1", @current_retry_attempt)
      end

      if Mode.commandline
        CommandLine.Print(message)
        CommandLine.Print(error)

        # ask user in the interactive mode
        if CommandLine.Interactive
          CommandLine.Print("")

          # command line mode - ask user whether installation of the failed package should be retried
          CommandLine.Print(_("Retry the installation?"))

          if CommandLine.YesNo
            # return Retry
            return ""
          end

          # command line mode - ask user whether the installation should be aborted
          CommandLine.Print(_("Skip the medium?"))
          if CommandLine.YesNo
            # return Skip
            return "S"
          end

          # otherwise ignore the medium
          CommandLine.Print(_("Ignoring the bad medium..."))
          return "I"
        end

        return "S"
      end

      Builtins.y2debug(
        "Opening Dialog: %1",
        LayoutPopup(message, button_box, 10, true)
      )

      if @showLongInfo
        UI.OpenDialog(
          Opt(:decorated),
          LayoutPopup(message, button_box, 10, true)
        )
        # TextEntry label
        UI.ReplaceWidget(
          Id(:info),
          VBox(
            InputField(Id(:url), Opt(:hstretch), _("&URL")),
            RichText(Opt(:plainText), error)
          )
        )
        UI.ChangeWidget(Id(:url), :Value, url)
      else
        UI.OpenDialog(
          Opt(:decorated),
          LayoutPopup(message, button_box, @vsize_no_details, false)
        )
        UI.ReplaceWidget(Id(:info), Empty())
      end

      # notification
      UI.Beep

      r = nil

      eject_device = ""
      begin
        if doing_auto_retry
          r = UI.TimeoutUserInput(1000)
        else
          r = UI.UserInput
        end

        # timout in autoretry mode?
        if doing_auto_retry
          if r == :timeout
            # decrease timeout counter
            @current_retry_timeout = Ops.subtract(@current_retry_timeout, 1)

            if @current_retry_timeout == 0
              Builtins.y2milestone("The time is out, doing automatic retry...")
              # do the retry
              r = :retry

              # decrease attempt counter
              @current_retry_attempt = Ops.add(@current_retry_attempt, 1)
            else
              # popup string - refresh the displayed counter
              UI.ChangeWidget(
                Id(:auto_retry),
                :Label,
                RetryLabel(@current_retry_timeout)
              )
            end
          else
            # user has pressed a button, reset the retry counter in the next timeout
            Builtins.y2milestone("User input: %1, resetting autoretry url", r)
            @retry_url = ""
          end
        end

        if r == :show
          @showLongInfo = ShowLogInfo(message, button_box)
          if @showLongInfo
            # TextEntry label
            UI.ReplaceWidget(
              Id(:info),
              VBox(
                TextEntry(Id(:url), _("&URL")),
                RichText(Opt(:plainText), error)
              )
            )
            UI.ChangeWidget(Id(:url), :Value, url)
          else
            UI.ReplaceWidget(Id(:info), Empty())
          end
        elsif r == :retry || r == :url
          if @showLongInfo # id(`url) must exist
            newurl = Convert.to_string(UI.QueryWidget(Id(:url), :Value))
            if newurl != url
              url = newurl
              r = :url
            end
          end
        elsif Ops.is_string?(r) &&
            Builtins.regexpmatch(Convert.to_string(r), "^/dev/")
          Builtins.y2milestone("Eject request for %1", r)
          eject_device = Convert.to_string(r)
          r = :eject
        end
      end until r == :cancel || r == :retry || r == :eject || r == :skip || r == :ignore ||
        r == :url

      # remember the state of autoeject option
      if offer_eject_button
        # check and save the autoeject configuration if needed
        CheckAndSaveAutoEject()
      end

      Builtins.y2milestone("MediaChange %1", r)

      UI.CloseDialog

      if @_provide_popup
        UI.CloseDialog
        @_provide_popup = false
      end

      if r == :cancel
        # abort during autorefresh should abort complete autorefresh, not only the failed repo
        if @autorefreshing
          @autorefreshing_aborted = true
          Pkg.SkipRefresh
        else
          @provide_aborted = true
        end

        return "C"
      end
      return "I" if r == :ignore
      return "S" if r == :skip
      if r == :eject
        @doing_eject = true

        if eject_device == ""
          return "E"
        else
          # get the index in the list
          dindex = -1

          found = Builtins.find(devices) do |d|
            dindex = Ops.add(dindex, 1)
            d == eject_device
          end

          if found != nil
            Builtins.y2milestone("Device %1 has index %2", eject_device, dindex)
            return Ops.add("E", Builtins.tostring(dindex))
          else
            Builtins.y2warning(
              "Device %1 not found in the list, using default",
              eject_device
            )
            return "E"
          end
        end
      end

      if r == :url
        Builtins.y2milestone("Redirecting to: %1", URL.HidePassword(url))
        return url
      end

      ""
    end


    # dummy repository change callback, see SlideShowCallbacks for the real one
    def SourceChange(source, medianr)
      Builtins.y2milestone("SourceChange (%1, %2)", source, medianr)
      @_current_source = source

      nil
    end


    def ProcessMessage(msg, max_len)
      words = Builtins.splitstring(msg, " ")

      Builtins.y2debug("words: %1", words)

      words = Builtins.maplist(words) do |w|
        parsed = URL.Parse(w)
        req_size = Ops.subtract(
          max_len,
          Ops.subtract(Builtins.size(msg), Builtins.size(w))
        )
        # is it a valid URL?
        if Builtins.contains(
            ["ftp", "http", "nfs", "file", "dir", "iso", "smb", "disk"],
            Ops.get_string(parsed, "scheme", "")
          )
          # reformat the URL
          w = URL.FormatURL(parsed, max_len)
        else
          if Builtins.substring(w, 0, 1) == "/"
            parts = Builtins.splitstring(w, "/")

            if Ops.greater_or_equal(Builtins.size(parts), 3)
              w = String.FormatFilename(w, req_size)
            end
          end
        end
        w
      end

      ret = Builtins.mergestring(words, " ")

      if ret != msg
        Builtins.y2milestone(
          "URL conversion: '%1' converted to '%2'",
          URL.HidePassword(msg),
          URL.HidePassword(ret)
        )
      end

      ret
    end

    def OpenSourcePopup
      if @_source_open == 0
        UI.OpenDialog(
          VBox(
            HSpacing(@max_size),
            Heading(Id(:label_source_popup), Opt(:hstretch), " "),
            ProgressBar(Id(:progress), " ", 100, 0)
          )
        )
      end

      @_source_open = Ops.add(@_source_open, 1)
      Builtins.y2milestone("OpenSourcePopup: _source_open: %1", @_source_open)

      nil
    end

    def SetHeaderSourcePopup(text)
      # Qt UI uses bold font, the string must be shortened even more
      ui_adjustment = textmode ? 0 : 5

      if Ops.greater_than(
          Builtins.size(text),
          Ops.subtract(@max_size, ui_adjustment)
        )
        text = ProcessMessage(text, Ops.subtract(@max_size, ui_adjustment))
      end

      UI.ChangeWidget(:label_source_popup, :Value, text)
      Builtins.y2milestone("SourcePopup: new header: %1", text)

      nil
    end

    def SetLabelSourcePopup(text)
      # Qt uses proportional font, the string might be longer
      ui_adjustment = textmode ? 0 : 6

      if Ops.greater_than(
          Builtins.size(text),
          Ops.add(@max_size, ui_adjustment)
        )
        text = ProcessMessage(text, Ops.add(@max_size, ui_adjustment))
      end

      # refresh the label in the popup
      UI.ChangeWidget(:progress, :Label, text)
      Builtins.y2milestone("SourcePopup: new label: %1", text)

      nil
    end

    # is the top level window source popup?
    def IsSourcePopup
      UI.WidgetExists(Id(:progress)) && UI.WidgetExists(Id(:label_source_popup))
    end

    def SourcePopupSetProgress(value)
      if Ops.greater_than(@_source_open, 0) && IsSourcePopup()
        UI.ChangeWidget(Id(:progress), :Value, value)
        input = UI.PollInput
        return false if input == :abort
      end
      true
    end

    def CloseSourcePopup
      if !IsSourcePopup()
        Builtins.y2error(
          "The toplevel dialog is not a repository popup dialog!"
        )
        return
      end

      @_source_open = Ops.subtract(@_source_open, 1)

      if @_source_open == 0
        Builtins.y2milestone("Closing repository progress popup")
        UI.CloseDialog
      end
      Builtins.y2milestone("CloseSourcePopup: _source_open: %1", @_source_open)

      nil
    end


    def SourceCreateInit
      Builtins.y2milestone("SourceCreateInit")

      OpenSourcePopup()

      nil
    end

    def SourceCreateDestroy
      Builtins.y2milestone("SourceCreateDestroy")

      CloseSourcePopup()

      nil
    end

    def SourceCreateStart(url)
      Builtins.y2milestone("SourceCreateStart: %1", url)

      # popup label (%1 is repository URL)
      msg = Builtins.sformat(_("Creating Repository %1"), url)

      if Mode.commandline
        CommandLine.Print(msg)
      else
        Builtins.y2milestone("_source_open: %1", @_source_open)

        if @_source_open == 1
          SetHeaderSourcePopup(msg)
        else
          SetLabelSourcePopup(msg)
        end
      end

      nil
    end

    def SourceCreateProgress(percent)
      ret = SourcePopupSetProgress(percent)
      Builtins.y2milestone("SourceCreateProgress(%1) = %2", percent, ret)

      ret
    end

    def SourceCreateError(url, error, description)
      Builtins.y2milestone(
        "Source create: error: url: %1, error: %2, description: %3",
        URL.HidePassword(url),
        error,
        description
      )

      # error message - a label followed by a richtext with details
      message = _("An error occurred while creating the repository.")

      if error == :NOT_FOUND
        # error message - a label followed by a richtext with details
        message = _("Unable to retrieve the remote repository description.")
      elsif error == :IO
        # error message - a label followed by a richtext with details
        message = _("An error occurred while retrieving the new metadata.")
      elsif error == :INVALID
        # error message - a label followed by a richtext with details
        message = _("The repository is not valid.")
      elsif error == :REJECTED
        # error message - a label followed by a richtext with details
        message = _("The repository metadata is invalid.")
      end

      if Mode.commandline
        CommandLine.Print(message)
        CommandLine.Print(URL.HidePassword(url))
        CommandLine.Print(description)

        # ask user in the interactive mode
        if CommandLine.Interactive
          CommandLine.Print("")

          # command line mode - ask user whether the repository refreshment should be retried
          CommandLine.Print(_("Retry?"))

          if CommandLine.YesNo
            # return Retry
            return :RETRY
          end
        end

        return :ABORT
      end
      detail = Builtins.sformat("%1<br>%2", url, description)
      UI.OpenDialog(
        VBox(
          Label(message),
          RichText(detail),
          ButtonBox(
            PushButton(Id(:RETRY), Opt(:okButton), Label.RetryButton),
            PushButton(Id(:ABORT), Opt(:cancelButton), Label.AbortButton)
          )
        )
      )
      ret = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog
      Builtins.y2milestone("Source create error: Returning %1", ret)

      ret
    end

    def SourceCreateEnd(url, error, description)
      # set 100% progress
      SourcePopupSetProgress(100)

      Builtins.y2milestone(
        "Source create end: error: url: %1, error: %2, description: %3",
        URL.HidePassword(url),
        error,
        description
      )

      nil
    end



    def SourceProbeStart(url)
      Builtins.y2milestone("SourceProbeStart: %1", URL.HidePassword(url))

      # popup label (%1 is repository URL)
      msg = Builtins.sformat(_("Probing Repository %1"), URL.HidePassword(url))

      if Mode.commandline
        CommandLine.Print(msg)
      else
        OpenSourcePopup()

        msg2 = Builtins.sformat(
          _("Probing Repository %1"),
          URL.HidePassword(url)
        )

        if @_source_open == 1
          SetHeaderSourcePopup(msg2)
        else
          SetLabelSourcePopup(msg2)
        end
      end

      nil
    end


    def SourceProbeFailed(url, type)
      Builtins.y2milestone(
        "Repository %1 is not %2 repository",
        URL.HidePassword(url),
        type
      )

      nil
    end

    def SourceProbeSucceeded(url, type)
      Builtins.y2milestone(
        "Repository %1 is type %2",
        URL.HidePassword(url),
        type
      )

      nil
    end


    def SourceProbeProgress(url, value)
      SourcePopupSetProgress(value)
    end

    def SourceProbeError(url, error, description)
      Builtins.y2milestone(
        "Source probe: error: url: %1, error: %2, description: %3",
        URL.HidePassword(url),
        error,
        description
      )

      # error message - a label followed by a richtext with details
      message = _("Error occurred while probing the repository.")

      if error == :NOT_FOUND
        # error message - a label followed by a richtext with details
        message = _("Unable to retrieve the remote repository description.")
      elsif error == :IO
        # error message - a label followed by a richtext with details
        message = _("An error occurred while retrieving the new metadata.")
      elsif error == :INVALID
        # error message - a label followed by a richtext with details
        message = _("The repository is not valid.")
      elsif error == :NO_ERROR
        # error message - a label followed by a richtext with details
        message = _("Repository probing details.")
      elsif error == :REJECTED
        # error message - a label followed by a richtext with details
        message = _("Repository metadata is invalid.")
      end

      if Mode.commandline
        CommandLine.Print(message)
        CommandLine.Print(URL.HidePassword(url))
        CommandLine.Print(description)

        # ask user in the interactive mode
        if CommandLine.Interactive
          CommandLine.Print("")

          # command line mode - ask user whether the repository refreshment should be retried
          CommandLine.Print(_("Retry?"))

          if CommandLine.YesNo
            # return Retry
            return :RETRY
          end
        end

        return :ABORT
      end
      detail = Builtins.sformat("%1<br>%2", url, description)
      UI.OpenDialog(
        VBox(
          Label(message),
          RichText(detail),
          ButtonBox(
            PushButton(Id(:RETRY), Opt(:okButton), Label.RetryButton),
            PushButton(Id(:ABORT), Opt(:cancelButton), Label.AbortButton)
          )
        )
      )
      ret = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog
      Builtins.y2milestone("Source probe error: Returning %1", ret)
      ret
    end

    def SourceProbeEnd(url, error, description)
      CloseSourcePopup()
      CloseSourcePopup()

      Builtins.y2milestone(
        "Source probe end: error: url: %1, error: %2, description: %3",
        URL.HidePassword(url),
        error,
        description
      )

      nil
    end


    def SourceReportStart(source_id, url, task)
      Builtins.y2milestone(
        "Source report start: src: %1, URL: %2, task: %3",
        source_id,
        URL.HidePassword(url),
        task
      )

      if Mode.commandline
        CommandLine.Print(task)
      else
        Builtins.y2milestone("_source_open: %1", @_source_open)

        if @_source_open == 1
          SetHeaderSourcePopup(task)
        else
          SetLabelSourcePopup(task)
        end
      end

      nil
    end

    def SourceReportProgress(value)
      ret = SourcePopupSetProgress(value)
      Builtins.y2debug("SourceReportProgress(%1) = %2", value, ret)

      ret
    end


    def SourceReportError(source_id, url, error, description)
      Builtins.y2milestone(
        "Source report: error: id: %1, url: %2, error: %3, description: %4",
        source_id,
        URL.HidePassword(url),
        error,
        description
      )

      # error message - a label followed by a richtext with details
      message = Builtins.sformat(_("Repository %1"), url)

      if error == :NOT_FOUND
        # error message - a label followed by a richtext with details
        message = _("Unable to retrieve the remote repository description.")
      elsif error == :IO
        # error message - a label followed by a richtext with details
        message = _("An error occurred while retrieving the new metadata.")
      elsif error == :INVALID
        # error message - a label followed by a richtext with details
        message = _("The repository is not valid.")
      end

      if Mode.commandline
        CommandLine.Print(message)
        CommandLine.Print(url)
        CommandLine.Print(description)

        # ask user in the interactive mode
        if CommandLine.Interactive
          CommandLine.Print("")

          # command line mode - ask user whether the repository refreshment should be retried
          CommandLine.Print(_("Retry?"))

          if CommandLine.YesNo
            # return Retry
            return :RETRY
          end
        end

        return :ABORT
      end
      detail = Builtins.sformat("%1<br>%2", url, description)
      UI.OpenDialog(
        VBox(
          Label(message),
          RichText(detail),
          HBox(
            PushButton(Id(:RETRY), Opt(:okButton), Label.RetryButton),
            PushButton(Id(:ABORT), Opt(:cancelButton), Label.AbortButton)
          )
        )
      )
      ret = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog
      Builtins.y2milestone("Source report error: Returning %1", ret)

      ret
    end

    def SourceReportEnd(src_id, url, task, error, description)
      Builtins.y2milestone(
        "Source report end: src: %1, url: %2, task: %3, error: %4, description: %5",
        src_id,
        URL.HidePassword(url),
        task,
        error,
        description
      )

      # set 100% progress
      SourcePopupSetProgress(100)

      nil
    end

    def SourceReportInit
      Builtins.y2milestone("Source report init")
      OpenSourcePopup()

      nil
    end

    def SourceReportDestroy
      Builtins.y2milestone("Source report destroy")
      CloseSourcePopup()

      nil
    end

    # at start of delta providal
    #
    def StartDeltaProvide(name, archivesize)
      sz = String.FormatSizeWithPrecision(archivesize, 2, false)
      if Mode.commandline
        CommandLine.PrintVerbose(
          Builtins.sformat(
            _("Downloading delta RPM package %1 (%2)..."),
            name,
            sz
          )
        )
      else
        UI.CloseDialog if @_provide_popup
        # popup heading
        providebox = ProgressBox(_("Downloading Delta RPM package"), name, sz)
        UI.OpenDialog(providebox)
        @_provide_popup = true
      end

      nil
    end

    # at start of delta application
    #
    def StartDeltaApply(name)
      if Mode.commandline
        CommandLine.PrintVerbose(
          Builtins.sformat(_("Applying delta RPM package %1..."), name)
        )
      else
        # popup heading
        progressbox = VBox(
          HSpacing(40),
          # popup heading
          Heading(_("Applying delta RPM package")),
          Left(
            HBox(Left(Label(Opt(:boldFont), _("Package: "))), Left(Label(name)))
          ),
          ProgressBar(Id(:progress), "", 100, 0)
        )
        UI.CloseDialog if @_provide_popup
        UI.OpenDialog(progressbox)
        @_provide_popup = true
      end

      nil
    end

    # at start of patch providal
    #
    def StartPatchProvide(name, archivesize)
      sz = String.FormatSizeWithPrecision(archivesize, 2, false)
      if Mode.commandline
        CommandLine.PrintVerbose(
          Builtins.sformat(
            _("Downloading patch RPM package %1 (%2)..."),
            name,
            sz
          )
        )
      else
        UI.CloseDialog if @_provide_popup
        # popup heading
        providebox = ProgressBox(_("Downloading Patch RPM Package"), name, sz)
        UI.OpenDialog(providebox)
        @_provide_popup = true
      end

      nil
    end

    def FinishPatchDeltaProvide
      if @_provide_popup
        UI.CloseDialog
        @_provide_popup = false
      end

      nil
    end

    def ProblemDeltaDownload(descr)
      FinishPatchDeltaProvide() # close popup
      Builtins.y2milestone("Failed to download delta RPM: %1", descr)

      nil
    end

    def ProblemDeltaApply(descr)
      FinishPatchDeltaProvide() # close popup
      Builtins.y2milestone("Failed to apply delta RPM: %1", descr)

      nil
    end

    def ProblemPatchDownload(descr)
      FinishPatchDeltaProvide() # close popup
      Builtins.y2milestone("Failed to download patch RPM: %1", descr)

      nil
    end


    def FormatPatchName(patch_name, patch_version, patch_arch)
      patch_full_name = patch_name != nil && patch_name != "" ? patch_name : ""

      if patch_full_name != ""
        if patch_version != nil && patch_version != ""
          patch_full_name = Ops.add(
            Ops.add(patch_full_name, "-"),
            patch_version
          )
        end

        if patch_arch != nil && patch_arch != ""
          patch_full_name = Ops.add(Ops.add(patch_full_name, "."), patch_arch)
        end
      end

      patch_full_name
    end

    def ScriptStart(patch_name, patch_version, patch_arch, script_path)
      patch_full_name = FormatPatchName(patch_name, patch_version, patch_arch)

      Builtins.y2milestone(
        "ScriptStart callback: patch: %1, script: %2",
        patch_full_name,
        script_path
      )

      if Mode.commandline
        CommandLine.PrintVerbose(
          Builtins.sformat(
            _("Starting script %1 (patch %2)..."),
            script_path,
            patch_full_name
          )
        )
      else
        progressbox = VBox(
          HSpacing(60),
          # popup heading
          Heading(_("Running Script")),
          VBox(
            patch_full_name != "" ?
              HBox(
                # label, patch name follows
                Label(Opt(:boldFont), _("Patch: ")),
                Label(patch_full_name),
                HStretch()
              ) :
              Empty(),
            HBox(
              # label, script name follows
              Label(Opt(:boldFont), _("Script: ")),
              Label(script_path),
              HStretch()
            )
          ),
          # label
          LogView(Id(:log), _("Output of the Script"), 10, 0),
          ButtonBox(
            PushButton(
              Id(:abort),
              Opt(:default, :key_F9, :cancelButton),
              Label.AbortButton
            )
          )
        )

        UI.CloseDialog if @_script_popup

        UI.OpenDialog(progressbox)
        UI.SetFocus(Id(:abort))

        @_script_popup = true
      end

      nil
    end

    def ScriptProgress(ping, output)
      Builtins.y2milestone("ScriptProgress: ping:%1, output: %2", ping, output)

      if @_script_popup
        if ping
          # TODO: refresh progress indicator
          Builtins.y2debug("-ping-")
        end

        if output != nil && output != ""
          # add the output to the log widget
          UI.ChangeWidget(Id(:log), :Value, output)
        end

        input = UI.PollInput
        return false if input == :abort || input == :close
      end
      true
    end

    def ScriptProblem(description)
      Builtins.y2warning("ScriptProblem: %1", description)

      ui = Popup.AnyQuestion3(
        "", #symbol focus
        description,
        Label.RetryButton, #yes_button_message
        Label.AbortButton, # no_button_message
        Label.IgnoreButton, #retry_button_message
        :retry
      )

      Builtins.y2milestone("Problem result: %1", ui)

      # Abort is the default
      ret = "A"

      if ui == :retry
        # ignore
        ret = "I"
      elsif ui == :yes
        # retry
        ret = "R"
      elsif ui == :no
        # abort
        ret = "A"
      else
        Builtins.y2warning("Unknown result: %1, aborting", ui)
      end

      ret
    end

    def ScriptFinish
      Builtins.y2milestone("ScriptFinish")

      UI.CloseDialog if @_script_popup

      nil
    end

    def Message(patch_name, patch_version, patch_arch, message)
      patch_full_name = FormatPatchName(patch_name, patch_version, patch_arch)
      Builtins.y2milestone("Message (%1): %2", patch_full_name, message)

      if patch_full_name != ""
        # label, %1 is patch name with version and architecture
        patch_full_name = Builtins.sformat(_("Patch: %1\n\n"), patch_full_name)
      end

      ret = Popup.ContinueCancel(Ops.add(patch_full_name, message))
      Builtins.y2milestone("User input: %1", ret)

      ret
    end

    def AskAbortRefresh
      UI.OpenDialog(
        MarginBox(
          1,
          0.5,
          VBox(
            # a popup question with "Continue", "Skip" and "Abort" buttons
            Label(
              _(
                "The repositories are being refreshed.\n" +
                  "Continue with refreshing?\n" +
                  "\n" +
                  "Note: If the refresh is skipped some packages\n" +
                  "might be missing or out of date."
              )
            ),
            ButtonBox(
              PushButton(
                Id(:continue),
                Opt(:default, :okButton),
                Label.ContinueButton
              ),
              # push button label
              PushButton(Id(:skip), Opt(:cancelButton), _("&Skip Refresh"))
            )
          )
        )
      )

      UI.SetFocus(Id(:continue))

      ui = Convert.to_symbol(UI.UserInput)

      UI.CloseDialog

      ui = :continue if ui == :close

      Builtins.y2milestone("User request: %1", ui)

      ui
    end

    def IsDownloadProgressPopup
      !Mode.commandline && UI.WidgetExists(Id(:download_progress_popup_window)) &&
        UI.WidgetExists(Id(:progress))
    end

    def CloseDownloadProgressPopup
      UI.CloseDialog if IsDownloadProgressPopup()

      nil
    end

    def InitDownload(task)
      if !Mode.commandline
        if !FullScreen() && !IsDownloadProgressPopup()
          # heading of popup
          heading = _("Downloading")

          UI.OpenDialog(
            Opt(:decorated),
            VBox(
              Heading(Id(:download_progress_popup_window), heading),
              VBox(
                HSpacing(60),
                HBox(
                  HSpacing(1),
                  ProgressBar(Id(:progress), task, 100),
                  HSpacing(1)
                ),
                VSpacing(0.5),
                ButtonBox(
                  PushButton(Id(:abort), Opt(:cancelButton), Label.AbortButton)
                ),
                VSpacing(0.5)
              )
            )
          )
          UI.ChangeWidget(Id(:progress), :Value, 0)
        end
      end

      nil
    end

    def DestDownload
      CloseDownloadProgressPopup() if !FullScreen()

      nil
    end

    def StartDownload(url, localfile)
      Builtins.y2milestone(
        "Downloading %1 to %2",
        URL.HidePassword(url),
        localfile
      )

      # heading of popup
      heading = _("Downloading")

      # reformat the URL
      url_report = URL.FormatURL(URL.Parse(URL.HidePassword(url)), @max_size)
      # remember the URL
      @download_file = url_report

      # message in a progress popup
      message = Builtins.sformat(_("Downloading: %1"), url_report)

      if Mode.commandline
        CommandLine.PrintVerbose(message)
      else
        if IsDownloadProgressPopup()
          # change the label
          UI.ChangeWidget(Id(:progress), :Label, message)
          UI.ChangeWidget(Id(:progress), :Value, 0)
        elsif FullScreen()
          Progress.SubprogressType(:progress, 100)
          Progress.SubprogressTitle(message)
        end
      end

      nil
    end

    def ProgressDownload(percent, bps_avg, bps_current)
      if @autorefreshing && @autorefreshing_aborted
        Builtins.y2milestone("Refresh aborted")
        return false
      end

      if Mode.commandline
        CommandLine.PrintVerboseNoCR(
          Ops.add(@clear_string, Builtins.sformat("%1%%", percent))
        )
        if percent == 100
          # sleep for a wile
          Builtins.sleep(200)
          # remove the progress
          CommandLine.PrintVerboseNoCR(@clear_string) 
          # print newline when reached 100%
        end
      else
        msg_rate = ""

        if Ops.greater_than(bps_current, 0)
          # do not show the average download rate if the space is limited
          bps_avg = -1 if textmode && Ops.less_than(display_width, 100)

          format = textmode ?
            Ops.add("%1 - ", @download_file) :
            Ops.add(@download_file, " - %1")

          # progress bar label, %1 is URL with optional download rate
          msg_rate = Builtins.sformat(
            _("Downloading: %1"),
            String.FormatRateMessage(format, bps_avg, bps_current)
          )
        end

        if FullScreen()
          Progress.SubprogressValue(percent)

          if Ops.greater_than(Builtins.size(msg_rate), 0)
            Progress.SubprogressTitle(msg_rate)
          end
        else
          UI.ChangeWidget(Id(:progress), :Value, percent)

          if Ops.greater_than(Builtins.size(msg_rate), 0)
            UI.ChangeWidget(Id(:progress), :Label, msg_rate)
          end
        end

        download_aborted = UI.PollInput == :abort

        if download_aborted && @autorefreshing
          # display "Continue", "Skip Refresh" dialog
          answer = AskAbortRefresh()

          if answer == :continue
            download_aborted = false
          elsif answer == :skip
            download_aborted = true
            @autorefreshing_aborted = true

            Pkg.SkipRefresh
          else
            Builtins.y2error("Unknown input value: %1", answer)
          end
        end

        return !download_aborted
      end

      true
    end

    # just log the status, errors are handled in MediaChange callback
    def DoneDownload(error_value, error_text)
      if error_value == 0
        Builtins.y2milestone("Download finished")
      else
        if @autorefreshing && @autorefreshing_aborted
          Builtins.y2milestone("Refresh aborted")
        else
          Builtins.y2warning(
            "Download failed: error %1: %2",
            error_value,
            error_text
          )
        end
      end

      nil
    end

    def RefreshStarted
      Builtins.y2milestone("Autorefreshing repositories...")

      if !Mode.commandline && UI.WidgetExists(Id(:abort))
        # push button label
        UI.ChangeWidget(Id(:abort), :Label, _("Skip Autorefresh"))
        UI.RecalcLayout
      end

      @autorefreshing = true
      @autorefreshing_aborted = false

      nil
    end

    def RefreshDone
      if !Mode.commandline && UI.WidgetExists(Id(:abort))
        UI.ChangeWidget(Id(:abort), :Label, Label.AbortButton)
        UI.RecalcLayout
      end

      Builtins.y2milestone("Autorefresh done")
      @autorefreshing = false
      @autorefreshing_aborted = false

      nil
    end

    def ClearDownloadCallbacks
      Pkg.CallbackInitDownload(nil)
      Pkg.CallbackStartDownload(nil)
      Pkg.CallbackProgressDownload(nil)
      Pkg.CallbackDoneDownload(nil)
      Pkg.CallbackDestDownload(nil)
      Pkg.CallbackStartRefresh(nil)
      Pkg.CallbackDoneRefresh(nil)

      nil
    end


    def StartRebuildDB
      # heading of popup
      heading = _("Checking Package Database")

      # message in a progress popup
      message = _(
        "Rebuilding package database. This process can take some time."
      )

      # progress bar label
      progress_label = _("Status")

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          Heading(heading),
          VBox(
            Label(message),
            HSpacing(60),
            HBox(HSpacing(2), ProgressBar(Id(:progress), "", 100), HSpacing(2)),
            VSpacing(1)
          )
        )
      )

      UI.ChangeWidget(Id(:progress), :Value, 0)

      nil
    end


    def ProgressRebuildDB(percent)
      UI.ChangeWidget(Id(:progress), :Value, percent)

      nil
    end


    def StopRebuildDB(error_value, error_text)
      if error_value != 0
        # error message, %1 is the cause for the error
        Popup.Error(
          Builtins.sformat(
            _("Rebuilding of package database failed:\n%1"),
            error_text
          )
        )
      end

      UI.CloseDialog

      nil
    end


    def NotifyRebuildDB
      nil
    end


    def SetRebuildDBCallbacks
      Pkg.CallbackStartRebuildDb(fun_ref(method(:StartRebuildDB), "void ()"))
      Pkg.CallbackProgressRebuildDb(
        fun_ref(method(:ProgressRebuildDB), "void (integer)")
      )
      Pkg.CallbackStopRebuildDb(
        fun_ref(method(:StopRebuildDB), "void (integer, string)")
      )
      Pkg.CallbackNotifyRebuildDb(fun_ref(method(:NotifyRebuildDB), "void ()"))

      nil
    end



    def StartConvertDB(unused1)
      # heading of popup
      heading = _("Checking Package Database")

      # message in a progress popup
      message = _(
        "Converting package database. This process can take some time."
      )

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          Heading(heading),
          VBox(
            Label(message),
            HSpacing(60),
            HBox(
              HSpacing(2),
              ProgressBar(Id(:progress), _("Status"), 100),
              HSpacing(2)
            ),
            VSpacing(1)
          )
        )
      )

      UI.ChangeWidget(Id(:progress), :Value, 0)

      nil
    end


    def ProgressConvertDB(percent, file)
      UI.ChangeWidget(Id(:progress), :Value, percent)

      nil
    end


    def StopConvertDB(error_value, error_text)
      if error_value != 0
        # error message, %1 is the cause for the error
        Popup.Error(
          Builtins.sformat(
            _("Conversion of package database failed:\n%1"),
            error_text
          )
        )
      end

      UI.CloseDialog

      nil
    end


    def NotifyConvertDB
      nil
    end


    def SetConvertDBCallbacks
      Pkg.CallbackStartConvertDb(
        fun_ref(method(:StartConvertDB), "void (string)")
      )
      Pkg.CallbackProgressConvertDb(
        fun_ref(method(:ProgressConvertDB), "void (integer, string)")
      )
      Pkg.CallbackStopConvertDb(
        fun_ref(method(:StopConvertDB), "void (integer, string)")
      )
      Pkg.CallbackNotifyConvertDb(fun_ref(method(:NotifyConvertDB), "void ()"))

      nil
    end



    # Callback for start RPM DB scan event
    def StartScanDb
      Builtins.y2milestone("Scanning RPM DB...")

      if Mode.commandline
        # progress message (command line mode)
        CommandLine.PrintVerbose(_("Reading RPM database..."))
      else
        if !FullScreen()
          UI.OpenDialog(
            VBox(
              HSpacing(60),
              # popup heading
              Heading(
                Id(:label_scanDB_popup),
                Opt(:hstretch),
                _("Reading Installed Packages")
              ),
              HBox(
                # progress bar label
                ProgressBar(
                  Id(:progress),
                  _("Scanning RPM database..."),
                  100,
                  0
                ), # TODO: allow Abort
                # 			,
                # 			`VBox(
                # 			    `Label(""),
                # 			    `PushButton(`id(`abort), Label::AbortButton())
                # 			)
                HSpacing(1)
              )
            )
          )

          @_scan_popup = true
        else
          Progress.Title(_("Scanning RPM database..."))
        end
      end

      nil
    end

    # Callback for RPM DB scan progress
    def ProgressScanDb(value)
      if Mode.commandline
        CommandLine.PrintVerboseNoCR(
          Ops.add(@clear_string, Builtins.sformat("%1%%", value))
        )
      else
        if @_scan_popup && UI.WidgetExists(Id(:label_scanDB_popup))
          UI.ChangeWidget(Id(:progress), :Value, value)
          cont = UI.PollInput != :abort

          Builtins.y2warning("Scan DB aborted") if !cont

          return cont
        elsif FullScreen()
          Progress.Step(value)
        end
      end

      # continue
      true
    end

    # Callback for error handling during RPM DB scan
    def ErrorScanDb(error, description)
      Builtins.y2error(
        "ErrorScanDb callback: error: %1, description: %2",
        error,
        description
      )

      # error message, could not read RPM database
      message = _("Initialization of the target failed.")

      if Mode.commandline
        CommandLine.Print(message)
        CommandLine.Print(description)

        # ask user in the interactive mode
        if CommandLine.Interactive
          CommandLine.Print("")

          # command line mode - ask user whether target initializatin can be restarted
          CommandLine.Print(_("Retry?"))

          if CommandLine.YesNo
            # return Retry
            return "R"
          end
        end

        # return Cancel
        return "C"
      end

      show_details = false

      button_box = ButtonBox(
        PushButton(Id(:abort), Opt(:cancelButton), Label.AbortButton),
        PushButton(Id(:retry), Opt(:customButton), Label.RetryButton),
        PushButton(Id(:ignore), Opt(:okButton), Label.IgnoreButton)
      )

      UI.OpenDialog(
        Opt(:decorated),
        LayoutPopup(message, button_box, @vsize_no_details, false)
      )

      r = nil
      begin
        r = UI.UserInput
        if r == :show
          show_details = ShowLogInfo(message, button_box)
          if show_details
            error_symbol = "UNKNOWN"

            if error == 0
              error_symbol = "NO_ERROR"
            elsif error == 1
              error_symbol = "FAILED"
            end

            UI.ReplaceWidget(
              Id(:info),
              RichText(
                Opt(:plainText),
                Ops.add(
                  # error message, %1 is code of the error,
                  # detail string is appended to the end
                  Builtins.sformat(_("Error: %1:"), error_symbol),
                  description
                )
              )
            )
          else
            UI.ReplaceWidget(Id(:info), Empty())
          end
        end
      end until r == :abort || r == :retry || r == :ignore

      Builtins.y2milestone("ErrorScanDb: user input: %1", r)

      UI.CloseDialog

      return "C" if r == :abort
      return "R" if r == :retry
      return "I" if r == :ignore

      Builtins.y2error("Unknown user input: %1", r)

      "C"
    end

    # Callback for finish RPM DB scan event
    def DoneScanDb(error, description)
      Builtins.y2milestone(
        "RPM DB scan finished: error: %1, reason: '%2'",
        error,
        description
      )

      if Mode.commandline
        # status message (command line mode)
        CommandLine.PrintVerbose(_("RPM database read"))
      else
        if @_scan_popup && UI.WidgetExists(Id(:label_scanDB_popup))
          UI.CloseDialog
          @_scan_popup = false
        elsif !FullScreen()
          Builtins.y2error("The toplevel dialog is not a scan DB popup!")
        end
      end

      nil
    end


    def Authentication(url, msg, username, password)

      # FIXME after SLE12 release
      # The following 'if' block is a workaround for bnc#895719 that should be
      # extracted to a proper private method (not sure if it will work as
      # expected being a callback) and adapted to use normal _() instead of
      # dgettext()
      url_query = URI(url).query
      if url_query
        url_params = Hash[URI.decode_www_form(url_query)]
        if url_params.has_key?("credentials")
          # Seems to be the url of a registration server, so add the tip to msg
          tip = Builtins.dgettext("registration",
                                  "Check that this system is known to the registration server.")
          msg = "#{tip}\n#{msg}"
        end
      end

      popup = VBox(
        HSpacing(50), # enforce width
        VSpacing(0.1),
        # heading in a popup window
        Heading(_("User Authentication")),
        VSpacing(0.1),
        HBox(
          HSpacing(0.1),
          RichText(
            Opt(:plainText),
            Builtins.sformat(_("URL: %1\n\n%2"), url, msg)
          ),
          HSpacing(0.1)
        ),
        VSpacing(0.1),
        HBox(
          HSpacing(1),
          VBox(
            # textentry label
            InputField(Id(:username), Opt(:hstretch), _("&User Name"), username),
            VSpacing(0.1),
            # textentry label
            Password(Id(:password), Opt(:hstretch), _("&Password"), password)
          ),
          HSpacing(1)
        ),
        VSpacing(0.5),
        ButtonBox(
          PushButton(Id(:cont), Opt(:default, :okButton), Label.ContinueButton),
          PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton)
        ),
        VSpacing(0.5)
      )

      UI.OpenDialog(Opt(:decorated), popup)

      ui = Convert.to_symbol(UI.UserInput)

      username = Convert.to_string(UI.QueryWidget(Id(:username), :Value))
      password = Convert.to_string(UI.QueryWidget(Id(:password), :Value))

      UI.CloseDialog

      {
        "username" => username,
        "password" => password,
        "continue" => ui == :cont
      }
    end

    def NextTick
      @current_tick = Ops.add(@current_tick, 1)
      if Ops.greater_or_equal(@current_tick, Builtins.size(@tick_labels))
        @current_tick = 0
      end

      nil
    end

    # is the top level progress popup?
    def IsProgressPopup
      UI.WidgetExists(Id(:progress_widget)) &&
        UI.WidgetExists(Id(:callback_progress_popup))
    end

    def ProgressStart(id, task, in_percent, is_alive, min, max, val_raw, val_percent)
      Builtins.y2milestone("ProgressStart: %1", id)

      @tick_progress = is_alive
      @val_progress = !in_percent && !is_alive
      @current_tick = 0
      @progress_task = task

      if Mode.commandline
        CommandLine.Print(task)
      else
        subprogress_type = @tick_progress ? :tick : :progress
        @progress_stack = Builtins.add(
          @progress_stack,
          { "type" => subprogress_type, "task" => task }
        )

        if IsProgressPopup() &&
            Ops.less_or_equal(Builtins.size(@progress_stack), 1)
          # huh, the popup is already there?
          Builtins.y2warning("Progress popup already opened...")
          UI.CloseDialog
        end

        if FullScreen()
          Progress.SubprogressType(subprogress_type, 100)
          Progress.SubprogressTitle(task)
        else
          UI.OpenDialog(
            HBox(
              HSpacing(1),
              VBox(
                VSpacing(0.5),
                HSpacing(Id(:callback_progress_popup), @max_size),
                in_percent ?
                  ProgressBar(Id(:progress_widget), task, 100, val_percent) :
                  BusyIndicator(Id(:progress_widget), task, 3000),
                VSpacing(0.2),
                ButtonBox(
                  PushButton(Id(:abort), Opt(:cancelButton), Label.AbortButton)
                ),
                VSpacing(0.5)
              ),
              HSpacing(1)
            )
          )
        end
      end

      nil
    end

    def ProgressEnd(id)
      Builtins.y2milestone("ProgressFinish: %1", id)

      # remove the last element from the progress stack
      @progress_stack = Builtins.remove(
        @progress_stack,
        Ops.subtract(Builtins.size(@progress_stack), 1)
      )

      if !Mode.commandline && IsProgressPopup()
        UI.CloseDialog if Builtins.size(@progress_stack) == 0
      elsif FullScreen()
        if Ops.greater_than(Builtins.size(@progress_stack), 0)
          progress_type = Ops.get_symbol(
            @progress_stack,
            [Ops.subtract(Builtins.size(@progress_stack), 1), "type"],
            :none
          )
          task = Ops.get_string(
            @progress_stack,
            [Ops.subtract(Builtins.size(@progress_stack), 1), "task"],
            ""
          )

          Progress.SubprogressType(progress_type, 100)
          Progress.SubprogressTitle(task)
        end
      end

      nil
    end

    def ProgressProgress(id, val_raw, val_percent)
      Builtins.y2debug("ProgressProgress: %1, %2%% ", id, val_percent)

      if Mode.commandline
        if @tick_progress
          tick_label = Ops.get(@tick_labels, @current_tick, "/")
          CommandLine.PrintVerboseNoCR(Ops.add(@clear_string, tick_label))
          NextTick()
        else
          CommandLine.PrintVerboseNoCR(
            Ops.add(@clear_string, Builtins.sformat("%1%%", val_percent))
          )
        end
      else
        if IsProgressPopup()
          if @tick_progress || @val_progress
            UI.ChangeWidget(Id(:progress_widget), :Alive, true)
          else
            UI.ChangeWidget(Id(:progress_widget), :Value, val_percent)
          end

          # aborted ?
          input = UI.PollInput
          if input == :abort
            Builtins.y2warning(
              "Callback %1 has been aborted at %2%% (raw: %3)",
              id,
              val_percent,
              val_raw
            )
            return false
          end
        elsif FullScreen()
          # fullscreen callbacks
          Progress.SubprogressValue(val_percent)
        end
      end

      true
    end

    # Hanler for ProcessStart callback - handle start of a package manager process
    # @param [String] task Decription of the task
    # @param [Array<String>] stages Descriptions of the stages
    # @param [String] help Help text describing the process
    def ProcessStart(task, stages, help)
      stages = deep_copy(stages)
      Builtins.y2milestone(
        "Process: Start: task: %1, stages: %2, help: %3",
        task,
        stages,
        help
      )
      Builtins.y2milestone(
        "Progress: status: %1, isrunning: %2",
        Progress.status,
        Progress.IsRunning
      )

      return if Mode.commandline

      opened = false

      if Progress.status
        if !Progress.IsRunning
          Builtins.y2milestone("Opening Wizard window...")
          Wizard.CreateDialog
          Wizard.SetDesktopIcon("sw_single")

          opened = true
        end

        # set 100% as max value
        Progress.New(task, "", 100, stages, [], help)
        Progress.Title(task)
        @last_stage = 0
      end

      @opened_wizard = Builtins.add(@opened_wizard, opened)
      Builtins.y2milestone("Wizard stack: %1", @opened_wizard)

      nil
    end

    # Hander for ProcessProgress callback - report total progress
    # @param [Fixnum] percent Total progress in percent
    def ProcessProgress(percent)
      Builtins.y2debug("Process: %1%%", percent)

      return true if Mode.commandline

      Progress.Step(percent)

      true
    end

    # Hander for ProcessNextStage callback - the current stage has been finished
    def ProcessNextStage
      Builtins.y2milestone("Setting stage: %1", @last_stage)

      return if Mode.commandline

      Progress.Stage(@last_stage, "", -1)

      @last_stage = Ops.add(@last_stage, 1)

      nil
    end

    # Hander for ProcessDone callback - the process has been finished
    def ProcessDone
      Builtins.y2milestone("Process: Finished")
      return if Mode.commandline

      idx = Ops.subtract(Builtins.size(@opened_wizard), 1)

      close = Ops.get(@opened_wizard, idx, false)
      @opened_wizard = Builtins.remove(@opened_wizard, idx)

      Builtins.y2milestone(
        "Close Wizard window: %1, new stack: %2",
        close,
        @opened_wizard
      )

      # set 100%
      Progress.Finish

      if close
        Builtins.y2milestone("Closing Wizard window...")
        Wizard.CloseDialog
      end

      nil
    end

    # Register callbacks for media change
    def SetMediaCallbacks
      Pkg.CallbackMediaChange(
        fun_ref(
          method(:MediaChange),
          "string (string, string, string, string, integer, string, integer, string, boolean, list <string>, integer)"
        )
      )
      Pkg.CallbackSourceChange(
        fun_ref(method(:SourceChange), "void (integer, integer)")
      )

      nil
    end


    def ClearScriptCallbacks
      Pkg.CallbackScriptStart(nil)
      Pkg.CallbackScriptProgress(nil)
      Pkg.CallbackScriptProblem(nil)
      Pkg.CallbackScriptFinish(nil)

      Pkg.CallbackMessage(nil)

      nil
    end

    def SetScriptCallbacks
      Pkg.CallbackScriptStart(
        fun_ref(method(:ScriptStart), "void (string, string, string, string)")
      )
      Pkg.CallbackScriptProgress(
        fun_ref(method(:ScriptProgress), "boolean (boolean, string)")
      )
      Pkg.CallbackScriptProblem(
        fun_ref(method(:ScriptProblem), "string (string)")
      )
      Pkg.CallbackScriptFinish(fun_ref(method(:ScriptFinish), "void ()"))

      Pkg.CallbackMessage(
        fun_ref(method(:Message), "boolean (string, string, string, string)")
      )

      nil
    end

    def SetScanDBCallbacks
      Pkg.CallbackStartScanDb(fun_ref(method(:StartScanDb), "void ()"))
      Pkg.CallbackProgressScanDb(
        fun_ref(method(:ProgressScanDb), "boolean (integer)")
      )
      Pkg.CallbackErrorScanDb(
        fun_ref(method(:ErrorScanDb), "string (integer, string)")
      )
      Pkg.CallbackDoneScanDb(
        fun_ref(method(:DoneScanDb), "void (integer, string)")
      )

      nil
    end

    def ResetScanDBCallbacks
      Pkg.CallbackStartScanDb(nil)
      Pkg.CallbackProgressScanDb(nil)
      Pkg.CallbackErrorScanDb(nil)
      Pkg.CallbackDoneScanDb(nil)

      nil
    end

    def SetDownloadCallbacks
      Pkg.CallbackInitDownload(fun_ref(method(:InitDownload), "void (string)"))
      Pkg.CallbackStartDownload(
        fun_ref(method(:StartDownload), "void (string, string)")
      )
      Pkg.CallbackProgressDownload(
        fun_ref(
          method(:ProgressDownload),
          "boolean (integer, integer, integer)"
        )
      )
      Pkg.CallbackDoneDownload(
        fun_ref(method(:DoneDownload), "void (integer, string)")
      )
      Pkg.CallbackDestDownload(fun_ref(method(:DestDownload), "void ()"))
      Pkg.CallbackStartRefresh(fun_ref(method(:RefreshStarted), "void ()"))
      Pkg.CallbackDoneRefresh(fun_ref(method(:RefreshDone), "void ()"))

      nil
    end

    def ResetDownloadCallbacks
      Pkg.CallbackInitDownload(nil)
      Pkg.CallbackStartDownload(nil)
      Pkg.CallbackProgressDownload(nil)
      Pkg.CallbackDoneDownload(nil)
      Pkg.CallbackDestDownload(nil)
      Pkg.CallbackStartRefresh(nil)
      Pkg.CallbackDoneRefresh(nil)

      nil
    end

    def SetSourceCreateCallbacks
      # source create callbacks
      Pkg.CallbackSourceCreateStart(
        fun_ref(method(:SourceCreateStart), "void (string)")
      )
      Pkg.CallbackSourceCreateProgress(
        fun_ref(method(:SourceCreateProgress), "boolean (integer)")
      )
      Pkg.CallbackSourceCreateError(
        fun_ref(method(:SourceCreateError), "symbol (string, symbol, string)")
      )
      Pkg.CallbackSourceCreateEnd(
        fun_ref(method(:SourceCreateEnd), "void (string, symbol, string)")
      )
      Pkg.CallbackSourceCreateInit(
        fun_ref(method(:SourceCreateInit), "void ()")
      )
      Pkg.CallbackSourceCreateDestroy(
        fun_ref(method(:SourceCreateDestroy), "void ()")
      )

      nil
    end

    def SetSourceProbeCallbacks
      # source probing callbacks
      Pkg.CallbackSourceProbeStart(
        fun_ref(method(:SourceProbeStart), "void (string)")
      )
      Pkg.CallbackSourceProbeFailed(
        fun_ref(method(:SourceProbeFailed), "void (string, string)")
      )
      Pkg.CallbackSourceProbeSucceeded(
        fun_ref(method(:SourceProbeSucceeded), "void (string, string)")
      )
      Pkg.CallbackSourceProbeProgress(
        fun_ref(method(:SourceProbeProgress), "boolean (string, integer)")
      )
      Pkg.CallbackSourceProbeError(
        fun_ref(method(:SourceProbeError), "symbol (string, symbol, string)")
      )
      Pkg.CallbackSourceProbeEnd(
        fun_ref(method(:SourceProbeEnd), "void (string, symbol, string)")
      )

      nil
    end

    def SetProcessCallbacks
      # register process callbacks (total progress)
      Pkg.CallbackProcessStart(
        fun_ref(method(:ProcessStart), "void (string, list <string>, string)")
      )
      Pkg.CallbackProcessProgress(
        fun_ref(method(:ProcessProgress), "boolean (integer)")
      )
      Pkg.CallbackProcessNextStage(
        fun_ref(method(:ProcessNextStage), "void ()")
      )
      Pkg.CallbackProcessDone(fun_ref(method(:ProcessDone), "void ()"))

      nil
    end

    def SetProvideCallbacks
      Pkg.CallbackStartProvide(
        fun_ref(method(:StartProvide), "void (string, integer, boolean)")
      )
      Pkg.CallbackProgressProvide(
        fun_ref(method(:ProgressProvide), "boolean (integer)")
      )
      Pkg.CallbackDoneProvide(
        fun_ref(method(:DoneProvide), "string (integer, string, string)")
      )
      Pkg.CallbackStartPackage(
        fun_ref(
          method(:StartPackage),
          "void (string, string, string, integer, boolean)"
        )
      )
      Pkg.CallbackProgressPackage(
        fun_ref(method(:ProgressPackage), "boolean (integer)")
      )
      Pkg.CallbackDonePackage(
        fun_ref(method(:DonePackage), "string (integer, string)")
      )

      nil
    end

    def SetPatchCallbacks
      Pkg.CallbackStartDeltaDownload(
        fun_ref(method(:StartDeltaProvide), "void (string, integer)")
      )
      Pkg.CallbackProgressDeltaDownload(
        fun_ref(method(:ProgressProvide), "boolean (integer)")
      )
      Pkg.CallbackProblemDeltaDownload(
        fun_ref(method(:ProblemDeltaDownload), "void (string)")
      )
      Pkg.CallbackFinishDeltaDownload(
        fun_ref(method(:FinishPatchDeltaProvide), "void ()")
      )

      Pkg.CallbackStartDeltaApply(
        fun_ref(method(:StartDeltaApply), "void (string)")
      )
      Pkg.CallbackProgressDeltaApply(
        fun_ref(method(:ProgressDeltaApply), "void (integer)")
      )
      Pkg.CallbackProblemDeltaApply(
        fun_ref(method(:ProblemDeltaApply), "void (string)")
      )
      Pkg.CallbackFinishDeltaApply(
        fun_ref(method(:FinishPatchDeltaProvide), "void ()")
      )

      Pkg.CallbackStartPatchDownload(
        fun_ref(method(:StartPatchProvide), "void (string, integer)")
      )
      Pkg.CallbackProgressPatchDownload(
        fun_ref(method(:ProgressProvide), "boolean (integer)")
      )
      Pkg.CallbackProblemPatchDownload(
        fun_ref(method(:ProblemPatchDownload), "void (string)")
      )
      Pkg.CallbackFinishPatchDownload(
        fun_ref(method(:FinishPatchDeltaProvide), "void ()")
      )

      nil
    end

    def SetSourceReportCallbacks
      # source report callbacks
      Pkg.CallbackSourceReportStart(
        fun_ref(method(:SourceReportStart), "void (integer, string, string)")
      )
      Pkg.CallbackSourceReportProgress(
        fun_ref(method(:SourceReportProgress), "boolean (integer)")
      )
      Pkg.CallbackSourceReportError(
        fun_ref(
          method(:SourceReportError),
          "symbol (integer, string, symbol, string)"
        )
      )
      Pkg.CallbackSourceReportEnd(
        fun_ref(
          method(:SourceReportEnd),
          "void (integer, string, string, symbol, string)"
        )
      )
      Pkg.CallbackSourceReportInit(
        fun_ref(method(:SourceReportInit), "void ()")
      )
      Pkg.CallbackSourceReportDestroy(
        fun_ref(method(:SourceReportDestroy), "void ()")
      )

      nil
    end

    def SetProgressReportCallbacks
      Pkg.CallbackProgressReportStart(
        fun_ref(
          method(:ProgressStart),
          "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
        )
      )
      Pkg.CallbackProgressReportProgress(
        fun_ref(
          method(:ProgressProgress),
          "boolean (integer, integer, integer)"
        )
      )
      Pkg.CallbackProgressReportEnd(
        fun_ref(method(:ProgressEnd), "void (integer)")
      )

      nil
    end

    # Register package manager callbacks
    def InitPackageCallbacks
      SetProcessCallbacks()

      SetProvideCallbacks()

      SetPatchCallbacks()

      SetSourceCreateCallbacks()

      SetSourceProbeCallbacks()

      SetSourceReportCallbacks()

      SetProgressReportCallbacks()

      # authentication callback
      Pkg.CallbackAuthentication(
        fun_ref(
          method(:Authentication),
          "map <string, any> (string, string, string, string)"
        )
      )

      # @see bugzilla #183821
      # Do not register these callbacks in case of AutoInstallation
      # And for AutoUpgrade neither (bnc#820166)
      if !(Mode.autoinst || Mode.autoupgrade)
        # Signature-related callbacks
        Pkg.CallbackAcceptUnsignedFile(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptUnsignedFile),
            "boolean (string, integer)"
          )
        )
        Pkg.CallbackAcceptUnknownGpgKey(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptUnknownGpgKey),
            "boolean (string, string, integer)"
          )
        )
        # During installation untrusted repositories are disabled to avoid
        # asking again
        gpg_callback = Stage.initial ? :import_gpg_key_or_disable : :ImportGpgKey
        Pkg.CallbackImportGpgKey(
          fun_ref(
            SignatureCheckCallbacks.method(gpg_callback),
            "boolean (map <string, any>, integer)"
          )
        )
        Pkg.CallbackAcceptVerificationFailed(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptVerificationFailed),
            "boolean (string, map <string, any>, integer)"
          )
        )
        Pkg.CallbackTrustedKeyAdded(
          fun_ref(
            SignatureCheckCallbacks.method(:TrustedKeyAdded),
            "void (map <string, any>)"
          )
        )
        Pkg.CallbackTrustedKeyRemoved(
          fun_ref(
            SignatureCheckCallbacks.method(:TrustedKeyRemoved),
            "void (map <string, any>)"
          )
        )
        Pkg.CallbackAcceptFileWithoutChecksum(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptFileWithoutChecksum),
            "boolean (string)"
          )
        )
        Pkg.CallbackAcceptWrongDigest(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptWrongDigest),
            "boolean (string, string, string)"
          )
        )
        Pkg.CallbackAcceptUnknownDigest(
          fun_ref(
            SignatureCheckCallbacks.method(:AcceptUnknownDigest),
            "boolean (string, string)"
          )
        )
      end

      SetMediaCallbacks()

      SetScriptCallbacks()

      SetScanDBCallbacks()

      SetDownloadCallbacks()

      nil
    end

    #=============================================================================
    #	constructor and callback init
    #=============================================================================

    def DummyProcessStart(param1, param2, param3)
      param2 = deep_copy(param2)
      Builtins.y2debug("Empty ProcessStart callback")

      nil
    end

    def DummyBooleanInteger(param1)
      Builtins.y2debug("Empty generic boolean(integer)->true callback")
      true
    end

    def DummyStringString(param1)
      Builtins.y2debug("Empty generic string(string)->\"\" callback")
      ""
    end

    def DummyVoid
      Builtins.y2debug("Empty generic void() callback")

      nil
    end

    def SetDummyProcessCallbacks
      Pkg.CallbackProcessStart(
        fun_ref(
          method(:DummyProcessStart),
          "void (string, list <string>, string)"
        )
      )
      Pkg.CallbackProcessProgress(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackProcessNextStage(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackProcessDone(fun_ref(method(:DummyVoid), "void ()"))

      nil
    end


    def DummyStartProvide(param1, param2, param3)
      Builtins.y2debug("Empty StartProvide callback")

      nil
    end

    def DummyDoneProvide(error, reason, name)
      Builtins.y2debug("Empty DoneProvide callback, returning 'I'")
      "I"
    end

    def DummyStartPackage(name, location, summary, installsize, is_delete)
      Builtins.y2debug("Empty StartPackage callback")

      nil
    end

    def DummyDonePackage(error, reason)
      Builtins.y2debug("Empty DonePackage callback, returning 'I'")
      "I"
    end

    def SetDummyProvideCallbacks
      Pkg.CallbackStartProvide(
        fun_ref(method(:DummyStartProvide), "void (string, integer, boolean)")
      )
      Pkg.CallbackProgressProvide(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackDoneProvide(
        fun_ref(method(:DummyDoneProvide), "string (integer, string, string)")
      )
      Pkg.CallbackStartPackage(
        fun_ref(
          method(:DummyStartPackage),
          "void (string, string, string, integer, boolean)"
        )
      )
      Pkg.CallbackProgressPackage(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackDonePackage(
        fun_ref(method(:DummyDonePackage), "string (integer, string)")
      )

      nil
    end

    def DummyVoidString(param1)
      Builtins.y2debug("Empty generic void(string) callback")

      nil
    end

    def DummyVoidInteger(param1)
      Builtins.y2debug("Empty generic void(integer) callback")

      nil
    end

    def DummyVoidIntegerString(param1, param2)
      Builtins.y2debug("Empty generic void(integer, string) callback")

      nil
    end

    def DummyVoidStringInteger(param1, param2)
      Builtins.y2debug("Empty generic void(string, integer) callback")

      nil
    end

    def DummyStringIntegerString(param1, param2)
      Builtins.y2debug("Empty generic string(integer, string) callback")
      ""
    end

    def SetDummyPatchCallbacks
      Pkg.CallbackStartDeltaDownload(
        fun_ref(method(:DummyVoidStringInteger), "void (string, integer)")
      )
      Pkg.CallbackProgressDeltaDownload(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackProblemDeltaDownload(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackFinishDeltaDownload(fun_ref(method(:DummyVoid), "void ()"))

      Pkg.CallbackStartDeltaApply(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackProgressDeltaApply(
        fun_ref(method(:DummyVoidInteger), "void (integer)")
      )
      Pkg.CallbackProblemDeltaApply(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackFinishDeltaApply(fun_ref(method(:DummyVoid), "void ()"))

      Pkg.CallbackStartPatchDownload(
        fun_ref(method(:DummyVoidStringInteger), "void (string, integer)")
      )
      Pkg.CallbackProgressPatchDownload(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackProblemPatchDownload(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackFinishPatchDownload(fun_ref(method(:DummyVoid), "void ()"))

      nil
    end

    def DummySourceCreateError(url, error, description)
      Builtins.y2debug("Empty SourceCreateError callback, returning `ABORT")
      :ABORT
    end

    def DummySourceCreateEnd(url, error, description)
      Builtins.y2debug("Empty SourceCreateEnd callback")

      nil
    end

    def SetDummySourceCreateCallbacks
      Pkg.CallbackSourceCreateStart(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackSourceCreateProgress(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackSourceCreateError(
        fun_ref(
          method(:DummySourceCreateError),
          "symbol (string, symbol, string)"
        )
      )
      Pkg.CallbackSourceCreateEnd(
        fun_ref(method(:DummySourceCreateEnd), "void (string, symbol, string)")
      )
      Pkg.CallbackSourceCreateInit(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackSourceCreateDestroy(fun_ref(method(:DummyVoid), "void ()"))

      nil
    end

    def DummySourceReportStart(source_id, url, task)
      Builtins.y2debug("Empty SourceReportStart callback")

      nil
    end
    def DummySourceReportError(source_id, url, error, description)
      Builtins.y2debug("Empty SourceReportError callback, returning `ABORT")
      :ABORT
    end
    def DummySourceReportEnd(src_id, url, task, error, description)
      Builtins.y2debug("Empty SourceReportEnd callback")

      nil
    end

    def SetDummySourceReportCallbacks
      # source report callbacks
      Pkg.CallbackSourceReportStart(
        fun_ref(
          method(:DummySourceReportStart),
          "void (integer, string, string)"
        )
      )
      Pkg.CallbackSourceReportProgress(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackSourceReportError(
        fun_ref(
          method(:DummySourceReportError),
          "symbol (integer, string, symbol, string)"
        )
      )
      Pkg.CallbackSourceReportEnd(
        fun_ref(
          method(:DummySourceReportEnd),
          "void (integer, string, string, symbol, string)"
        )
      )
      Pkg.CallbackSourceReportInit(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackSourceReportDestroy(fun_ref(method(:DummyVoid), "void ()"))

      nil
    end

    def DummyProgressStart(id, task, in_percent, is_alive, min, max, val_raw, val_percent)
      Builtins.y2debug("Empty ProgressStart callback")

      nil
    end
    def DummyProgressProgress(id, val_raw, val_percent)
      Builtins.y2debug("Empty ProgressProgress callback, returning true")
      true
    end

    def SetDummyProgressReportCallbacks
      Pkg.CallbackProgressReportStart(
        fun_ref(
          method(:DummyProgressStart),
          "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
        )
      )
      Pkg.CallbackProgressReportProgress(
        fun_ref(
          method(:DummyProgressProgress),
          "boolean (integer, integer, integer)"
        )
      )
      Pkg.CallbackProgressReportEnd(
        fun_ref(method(:DummyVoidInteger), "void (integer)")
      )

      nil
    end

    def DummyScriptStart(patch_name, patch_version, patch_arch, script_path)
      Builtins.y2debug("Empty ScriptStart callback")

      nil
    end
    def DummyScriptProgress(ping, output)
      Builtins.y2debug("Empty ScriptProgress callback, returning true")
      true
    end
    def DummyMessage(patch_name, patch_version, patch_arch, message)
      Builtins.y2debug("Empty Message callback")
      true # continue
    end

    def SetDummyScriptCallbacks
      Pkg.CallbackScriptStart(
        fun_ref(
          method(:DummyScriptStart),
          "void (string, string, string, string)"
        )
      )
      Pkg.CallbackScriptProgress(
        fun_ref(method(:DummyScriptProgress), "boolean (boolean, string)")
      )
      Pkg.CallbackScriptProblem(
        fun_ref(method(:DummyStringString), "string (string)")
      )
      Pkg.CallbackScriptFinish(fun_ref(method(:DummyVoid), "void ()"))

      Pkg.CallbackMessage(
        fun_ref(
          method(:DummyMessage),
          "boolean (string, string, string, string)"
        )
      )

      nil
    end

    def SetDummyScanDBCallbacks
      Pkg.CallbackStartScanDb(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackProgressScanDb(
        fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
      )
      Pkg.CallbackErrorScanDb(
        fun_ref(method(:DummyStringIntegerString), "string (integer, string)")
      )
      Pkg.CallbackDoneScanDb(
        fun_ref(method(:DummyVoidIntegerString), "void (integer, string)")
      )

      nil
    end

    def DummyStartDownload(url, localfile)
      Builtins.y2debug("Empty StartDownload callback")

      nil
    end
    def DummyProgressDownload(percent, bps_avg, bps_current)
      Builtins.y2debug("Empty ProgressDownload callback, returning true")
      true
    end
    def DummyDoneDownload(error_value, error_text)
      Builtins.y2debug("Empty DoneDownload callback")

      nil
    end

    def SetDummyDownloadCallbacks
      Pkg.CallbackInitDownload(
        fun_ref(method(:DummyVoidString), "void (string)")
      )
      Pkg.CallbackStartDownload(
        fun_ref(method(:DummyStartDownload), "void (string, string)")
      )
      Pkg.CallbackProgressDownload(
        fun_ref(
          method(:DummyProgressDownload),
          "boolean (integer, integer, integer)"
        )
      )
      Pkg.CallbackDoneDownload(
        fun_ref(method(:DummyDoneDownload), "void (integer, string)")
      )
      Pkg.CallbackDestDownload(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackStartRefresh(fun_ref(method(:DummyVoid), "void ()"))
      Pkg.CallbackDoneRefresh(fun_ref(method(:DummyVoid), "void ()"))

      nil
    end


    def RegisterEmptyProgressCallbacks
      SetDummyProcessCallbacks()

      SetDummyProvideCallbacks()

      SetDummyPatchCallbacks()

      SetDummySourceCreateCallbacks()

      SetDummySourceReportCallbacks()

      SetDummyProgressReportCallbacks()

      SetDummyScriptCallbacks()

      SetDummyScanDBCallbacks()

      SetDummyDownloadCallbacks()

      nil
    end

    def RestoreProcessCallbacks
      Pkg.CallbackProcessStart(nil)
      Pkg.CallbackProcessProgress(nil)
      Pkg.CallbackProcessNextStage(nil)
      Pkg.CallbackProcessDone(nil)

      nil
    end

    def RestoreProvideCallbacks
      Pkg.CallbackStartProvide(nil)
      Pkg.CallbackProgressProvide(nil)
      Pkg.CallbackDoneProvide(nil)
      Pkg.CallbackStartPackage(nil)
      Pkg.CallbackProgressPackage(nil)
      Pkg.CallbackDonePackage(nil)

      nil
    end

    def RestorePatchCallbacks
      Pkg.CallbackStartDeltaDownload(nil)
      Pkg.CallbackProgressDeltaDownload(nil)
      Pkg.CallbackProblemDeltaDownload(nil)
      Pkg.CallbackFinishDeltaDownload(nil)

      Pkg.CallbackStartDeltaApply(nil)
      Pkg.CallbackProgressDeltaApply(nil)
      Pkg.CallbackProblemDeltaApply(nil)
      Pkg.CallbackFinishDeltaApply(nil)

      Pkg.CallbackStartPatchDownload(nil)
      Pkg.CallbackProgressPatchDownload(nil)
      Pkg.CallbackProblemPatchDownload(nil)
      Pkg.CallbackFinishPatchDownload(nil)

      nil
    end

    def RestoreSourceCreateCallbacks
      Pkg.CallbackSourceCreateStart(nil)
      Pkg.CallbackSourceCreateProgress(nil)
      Pkg.CallbackSourceCreateError(nil)
      Pkg.CallbackSourceCreateEnd(nil)
      Pkg.CallbackSourceCreateInit(nil)
      Pkg.CallbackSourceCreateDestroy(nil)

      nil
    end

    def RestoreSourceReportCallbacks
      Pkg.CallbackSourceReportStart(nil)
      Pkg.CallbackSourceReportProgress(nil)
      Pkg.CallbackSourceReportError(nil)
      Pkg.CallbackSourceReportEnd(nil)
      Pkg.CallbackSourceReportInit(nil)
      Pkg.CallbackSourceReportDestroy(nil)

      nil
    end

    def RestoreProgressReportCallbacks
      Pkg.CallbackProgressReportStart(nil)
      Pkg.CallbackProgressReportProgress(nil)
      Pkg.CallbackProgressReportEnd(nil)

      nil
    end


    def RestorePreviousProgressCallbacks
      RestoreProcessCallbacks()

      RestoreProvideCallbacks()

      RestorePatchCallbacks()

      RestoreSourceCreateCallbacks()

      RestoreSourceReportCallbacks()

      RestoreProgressReportCallbacks()

      ClearScriptCallbacks()

      ResetScanDBCallbacks()

      ResetDownloadCallbacks()

      nil
    end

    # constructor

    def PackageCallbacks
      Builtins.y2milestone("PackageCallbacks constructor")
      InitPackageCallbacks()

      nil
    end

    publish :variable => :_provide_popup, :type => "boolean"
    publish :variable => :_source_popup, :type => "boolean"
    publish :variable => :_package_popup, :type => "boolean"
    publish :variable => :_script_popup, :type => "boolean"
    publish :variable => :_scan_popup, :type => "boolean"
    publish :variable => :_package_name, :type => "string"
    publish :variable => :_package_size, :type => "integer"
    publish :variable => :_deleting_package, :type => "boolean"
    publish :variable => :_current_source, :type => "integer"
    publish :function => :StartProvide, :type => "void (string, integer, boolean)"
    publish :function => :ProgressProvide, :type => "boolean (integer)"
    publish :function => :ProgressDeltaApply, :type => "void (integer)"
    publish :function => :LayoutPopup, :type => "term (string, term, integer, boolean)"
    publish :function => :ShowLogInfo, :type => "boolean (string, term)"
    publish :function => :DoneProvide, :type => "string (integer, string, string)"
    publish :function => :EnableAsterixPackage, :type => "boolean (boolean)"
    publish :function => :StartPackage, :type => "void (string, string, string, integer, boolean)"
    publish :function => :ProgressPackage, :type => "boolean (integer)"
    publish :function => :DonePackage, :type => "string (integer, string)"
    publish :function => :CDdevices, :type => "list <term> (string)"
    publish :function => :MediaChange, :type => "string (string, string, string, string, integer, string, integer, string, boolean, list <string>, integer)"
    publish :function => :SourceChange, :type => "void (integer, integer)"
    publish :function => :SourceCreateInit, :type => "void ()"
    publish :function => :SourceCreateDestroy, :type => "void ()"
    publish :function => :SourceCreateStart, :type => "void (string)"
    publish :function => :SourceCreateProgress, :type => "boolean (integer)"
    publish :function => :SourceCreateError, :type => "symbol (string, symbol, string)"
    publish :function => :SourceCreateEnd, :type => "void (string, symbol, string)"
    publish :function => :SourceProbeStart, :type => "void (string)"
    publish :function => :SourceProbeFailed, :type => "void (string, string)"
    publish :function => :SourceProbeSucceeded, :type => "void (string, string)"
    publish :function => :SourceProbeProgress, :type => "boolean (string, integer)"
    publish :function => :SourceProbeError, :type => "symbol (string, symbol, string)"
    publish :function => :SourceProbeEnd, :type => "void (string, symbol, string)"
    publish :function => :SourceReportStart, :type => "void (integer, string, string)"
    publish :function => :SourceReportProgress, :type => "boolean (integer)"
    publish :function => :SourceReportError, :type => "symbol (integer, string, symbol, string)"
    publish :function => :SourceReportEnd, :type => "void (integer, string, string, symbol, string)"
    publish :function => :SourceReportInit, :type => "void ()"
    publish :function => :SourceReportDestroy, :type => "void ()"
    publish :function => :StartDeltaProvide, :type => "void (string, integer)"
    publish :function => :StartDeltaApply, :type => "void (string)"
    publish :function => :StartPatchProvide, :type => "void (string, integer)"
    publish :function => :FinishPatchDeltaProvide, :type => "void ()"
    publish :function => :ProblemDeltaDownload, :type => "void (string)"
    publish :function => :ProblemDeltaApply, :type => "void (string)"
    publish :function => :ProblemPatchDownload, :type => "void (string)"
    publish :function => :FormatPatchName, :type => "string (string, string, string)"
    publish :function => :ScriptStart, :type => "void (string, string, string, string)"
    publish :function => :ScriptProgress, :type => "boolean (boolean, string)"
    publish :function => :ScriptProblem, :type => "string (string)"
    publish :function => :ScriptFinish, :type => "void ()"
    publish :function => :Message, :type => "boolean (string, string, string, string)"
    publish :function => :AskAbortRefresh, :type => "symbol ()"
    publish :function => :IsDownloadProgressPopup, :type => "boolean ()"
    publish :function => :CloseDownloadProgressPopup, :type => "void ()"
    publish :function => :InitDownload, :type => "void (string)"
    publish :function => :DestDownload, :type => "void ()"
    publish :function => :StartDownload, :type => "void (string, string)"
    publish :function => :ProgressDownload, :type => "boolean (integer, integer, integer)"
    publish :function => :DoneDownload, :type => "void (integer, string)"
    publish :function => :RefreshStarted, :type => "void ()"
    publish :function => :RefreshDone, :type => "void ()"
    publish :function => :ClearDownloadCallbacks, :type => "void ()"
    publish :function => :StartRebuildDB, :type => "void ()"
    publish :function => :ProgressRebuildDB, :type => "void (integer)"
    publish :function => :StopRebuildDB, :type => "void (integer, string)"
    publish :function => :NotifyRebuildDB, :type => "void ()"
    publish :function => :SetRebuildDBCallbacks, :type => "void ()"
    publish :function => :StartConvertDB, :type => "void (string)"
    publish :function => :ProgressConvertDB, :type => "void (integer, string)"
    publish :function => :StopConvertDB, :type => "void (integer, string)"
    publish :function => :NotifyConvertDB, :type => "void ()"
    publish :function => :SetConvertDBCallbacks, :type => "void ()"
    publish :function => :StartScanDb, :type => "void ()"
    publish :function => :ProgressScanDb, :type => "boolean (integer)"
    publish :function => :ErrorScanDb, :type => "string (integer, string)"
    publish :function => :DoneScanDb, :type => "void (integer, string)"
    publish :function => :Authentication, :type => "map <string, any> (string, string, string, string)"
    publish :function => :ProgressStart, :type => "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
    publish :function => :ProgressEnd, :type => "void (integer)"
    publish :function => :ProgressProgress, :type => "boolean (integer, integer, integer)"
    publish :function => :ProcessStart, :type => "void (string, list <string>, string)"
    publish :function => :ProcessProgress, :type => "boolean (integer)"
    publish :function => :ProcessNextStage, :type => "void ()"
    publish :function => :ProcessDone, :type => "void ()"
    publish :function => :SetMediaCallbacks, :type => "void ()"
    publish :function => :ClearScriptCallbacks, :type => "void ()"
    publish :function => :SetScriptCallbacks, :type => "void ()"
    publish :function => :SetScanDBCallbacks, :type => "void ()"
    publish :function => :ResetScanDBCallbacks, :type => "void ()"
    publish :function => :SetDownloadCallbacks, :type => "void ()"
    publish :function => :ResetDownloadCallbacks, :type => "void ()"
    publish :function => :SetSourceCreateCallbacks, :type => "void ()"
    publish :function => :SetSourceProbeCallbacks, :type => "void ()"
    publish :function => :SetProcessCallbacks, :type => "void ()"
    publish :function => :SetProvideCallbacks, :type => "void ()"
    publish :function => :SetPatchCallbacks, :type => "void ()"
    publish :function => :SetSourceReportCallbacks, :type => "void ()"
    publish :function => :SetProgressReportCallbacks, :type => "void ()"
    publish :function => :InitPackageCallbacks, :type => "void ()"
    publish :function => :SetDummyProcessCallbacks, :type => "void ()"
    publish :function => :SetDummyProvideCallbacks, :type => "void ()"
    publish :function => :SetDummyPatchCallbacks, :type => "void ()"
    publish :function => :SetDummySourceCreateCallbacks, :type => "void ()"
    publish :function => :SetDummySourceReportCallbacks, :type => "void ()"
    publish :function => :SetDummyProgressReportCallbacks, :type => "void ()"
    publish :function => :SetDummyScriptCallbacks, :type => "void ()"
    publish :function => :SetDummyScanDBCallbacks, :type => "void ()"
    publish :function => :SetDummyDownloadCallbacks, :type => "void ()"
    publish :function => :RegisterEmptyProgressCallbacks, :type => "void ()"
    publish :function => :RestoreProcessCallbacks, :type => "void ()"
    publish :function => :RestoreProvideCallbacks, :type => "void ()"
    publish :function => :RestorePatchCallbacks, :type => "void ()"
    publish :function => :RestoreSourceCreateCallbacks, :type => "void ()"
    publish :function => :RestoreSourceReportCallbacks, :type => "void ()"
    publish :function => :RestoreProgressReportCallbacks, :type => "void ()"
    publish :function => :RestorePreviousProgressCallbacks, :type => "void ()"
    publish :function => :PackageCallbacks, :type => "void ()"
  end

  PackageCallbacks = PackageCallbacksClass.new
  PackageCallbacks.main
end
