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
# File:	modules/FileChanges.ycp
# Module:	yast2
# Summary:	Detect if a configuratil file was changed
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# Support routines for detecting changes of configuration files being done
# externally (not by YaST) to prevent the changes from being lost because
# of YaST not handling the configuration files correctly (eg. removing
# comments in some cases, changing order of options,...)
#
# Warns user if such change is detected.
#
# Usage:
# Before reading the configuration file:
#   call boolean CheckFiles (list<string>) with all files. If any of them
#   is detected to be changed, YaST asks a popup for you.
#   alternatively use boolean FileChanged (string) for each file (does not
#   ask any question, immediatelly returns status of the file
#
# After writing the configuraiton file:
#   call void StoreFileCheckSum (string) for each file to store recent
#   checksum. YaST will use this checksum next time checking.
#
require "yast"

module Yast
  class FileChangesClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Directory"
      Yast.import "Label"
      Yast.import "FileUtils"

      @data_file = "/var/lib/YaST2/file_checksums.ycp"

      @file_checksums = {}
    end

    # Read the data file containing file checksums
    def ReadSettings
      if Ops.less_or_equal(
        Convert.to_integer(SCR.Read(path(".target.size"), @data_file)),
        0
      )
        @file_checksums = {}
        return
      end
      @file_checksums = Convert.convert(
        SCR.Read(path(".target.ycp"), @data_file),
        from: "any",
        to:   "map <string, string>"
      )
      @file_checksums = {} if @file_checksums.nil?

      nil
    end

    # Write the data file containing checksums
    def WriteSettings
      SCR.Write(path(".target.ycp"), @data_file, @file_checksums)

      nil
    end

    # Compute the checksum of a file
    # @param [String] file string the file to compute checksum of
    # @return [String] the checksum
    def ComputeFileChecksum(file)
      # See also FileUtils::MD5sum()
      cmd = Builtins.sformat("/usr/bin/md5sum %1", file)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      # note: it also contains file name, but since it is only to be compared
      # it does not matter
      sum = Ops.get_string(out, "stdout", "")
      sum
    end

    # Check if file was modified compared to the one distributed
    # with the RPM package
    # @param [String] file string the file to check
    # @return [Boolean] true of was changed
    def FileChangedFromPackage(file)
      # queryformat: no trailing newline!
      cmd = Builtins.sformat(
        "/bin/rpm -qf %1 --qf %%{NAME}-%%{VERSION}-%%{RELEASE}",
        file
      )
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      package = Ops.get_string(out, "stdout", "")
      Builtins.y2milestone("Package owning %1: %2", file, package)
      return false if package == "" || Ops.get_integer(out, "exit", -1) != 0
      cmd = Builtins.sformat("rpm -V %1 |grep ' %2$'", package, file)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      changes = Ops.get_string(out, "stdout", "")
      Builtins.y2milestone("File possibly changed: %1", changes)
      lines = Builtins.splitstring(changes, "\n")
      changed = false
      Builtins.foreach(lines) do |line|
        changed = true if Builtins.regexpmatch(line, "^S")
        changed = true if Builtins.regexpmatch(line, "^..5")
        changed = true if Builtins.regexpmatch(line, "^.......T")
      end
      changed
    end

    # Check if a file was modified externally (without YaST)
    # @param [String] file string boolean the file to check
    # @return [Boolean] true if was changed externally
    def FileChanged(file)
      # when generating AutoYaST configuration, they are not written back
      return false if Mode.config
      ReadSettings()
      ret = false
      if Builtins.haskey(@file_checksums, file)
        Builtins.y2milestone("Comparing file %1 to stored checksum", file)
        sum = ComputeFileChecksum(file)
        ret = !(sum == Ops.get(@file_checksums, file, ""))
      else
        Builtins.y2milestone("Comparing file %1 to RPM database", file)
        ret = FileChangedFromPackage(file)
      end
      Builtins.y2milestone("File differs: %1", ret)
      ret
    end

    # Store checksum of a file to the store
    # @param [String] file string filename to compute and store
    def StoreFileCheckSum(file)
      ReadSettings()
      sum = ComputeFileChecksum(file)
      Ops.set(@file_checksums, file, sum)
      WriteSettings()

      nil
    end

    # Check files if any of them were changed
    # Issue a question whether to continue if some were chaned
    # @param [Array<String>] files a list of files to check
    # @return [Boolean] true if either none was changed or user agreed
    #  to continue
    def CheckFiles(files)
      files = deep_copy(files)
      files = Builtins.filter(files) { |f| FileChanged(f) }

      return true unless Ops.greater_than(Builtins.size(files), 0)

      msg = if Ops.greater_than(Builtins.size(files), 1)
        # Continue/Cancel question, %1 is a coma separated list of file names
        _("Files %1 have been changed manually.\nYaST might lose some of the changes")
      else
        # Continue/Cancel question, %1 is a file name
        _("File %1 has been changed manually.\nYaST might lose some of the changes.\n")
      end

      msg = Builtins.sformat(msg, Builtins.mergestring(files, ", "))
      popup_file = "/filechecks_non_verbose"

      return true unless {} ==
          SCR.Read(
            path(".target.stat"),
            Ops.add(Directory.vardir, popup_file)
          )

      content = VBox(
        Label(msg),
        Left(CheckBox(Id(:disable), _("Do not show this message anymore"))),
        ButtonBox(
          PushButton(Id(:ok), Opt(:okButton), Label.ContinueButton),
          PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton)
        )
      )
      UI.OpenDialog(content)
      UI.SetFocus(:ok)

      ret = UI.UserInput
      Builtins.y2milestone("ret = %1", ret)

      if ret == :ok && Convert.to_boolean(UI.QueryWidget(:disable, :Value))
        Builtins.y2milestone("Disabled checksum popups")
        SCR.Write(
          path(".target.string"),
          Ops.add(Directory.vardir, popup_file),
          ""
        )
      end
      UI.CloseDialog
      ret == :ok
    end

    # Check if any of the possibly new created files is really new
    # Issue a question whether to continue if such file was manually created
    # @param [Array<String>] files a list of files to check
    # @return [Boolean] true if either none was changed or user agreed
    #  to continue

    def CheckNewCreatedFiles(files)
      new_files = files - @file_checksums.keys

      return true unless new_files.size > 0

      # Continue/Cancel question, %s is a file name
      msg = _("File %s has been created manually.\nYaST might lose this file.")
      if new_files.size > 1
        # Continue/Cancel question, %s is a comma separated list of file names
        msg = _(
          "Files %s have been created manually.\nYaST might lose these files."
        )
      end
      msg = msg % new_files.join(", ")
      popup_file = "/filechecks_non_verbose"
      popup_file_path = File.join(Directory.vardir, popup_file)

      return true if FileUtils.Exists(popup_file_path)

      content = VBox(
        Label(msg),
        Left(CheckBox(Id(:disable), Message.DoNotShowMessageAgain())),
        ButtonBox(
          PushButton(Id(:ok), Opt(:okButton), Label.ContinueButton()),
          PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton())
        )
      )
      UI.OpenDialog(content)
      UI.SetFocus(:ok)
      ret = UI.UserInput
      Builtins.y2milestone("ret = %1", ret)
      if ret == :ok && UI.QueryWidget(:disable, :Value)
        Builtins.y2milestone("Disabled checksum popups")
        SCR.Write(
          path(".target.string"),
          popup_file_path,
          ""
        )
      end
      UI.CloseDialog
      return ret == :ok
    end

    publish function: :FileChanged, type: "boolean (string)"
    publish function: :StoreFileCheckSum, type: "void (string)"
    publish function: :CheckFiles, type: "boolean (list <string>)"
    publish function: :CheckNewCreatedFiles, type: "boolean (list <string>)"
  end

  FileChanges = FileChangesClass.new
  FileChanges.main
end
