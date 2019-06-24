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

require "yast/core_ext"

require "shellwords"

require "yast2/popup"

Yast.import "UI"
Yast.import "CommandLine"
Yast.import "Directory"
Yast.import "FileUtils"
Yast.import "Label"
Yast.import "Package"

module Yast
  # Reads a \n separated list of filenames from
  # /var/lib/YaST2/filenames
  # Lines starting with "#" are ignored (comments)
  # A line starting with "*" is taken as the default filename, the "*" is stripped
  #
  # All files are listed in an editable combo box, where the user can
  # easily switch between files and even add a new file
  #
  # At finish, the list of filenames is written back to
  # /var/lib/YaST2/filenames
  # adapting the default line (starting with "*") accordingly.
  #
  # The default is either given as WFM::Args(0) or is the file last viewed.
  class ViewAnymsgClient < Client
    using Yast::CoreExt::AnsiString

    # [String] Default list of log files
    DEFAULT_FILENAMES = [
      "/var/log/boot.log",
      "/var/log/messages",
      "/var/log/YaST2/y2log"
    ].freeze

    def main
      textdomain "base"

      # the command line description map
      return CommandLine.Run("id" => "view_anymsg") if WFM.Args.first == "help"

      # set up dialogue
      UI.OpenDialog(
        Opt(:decorated, :defaultsize),
        dialog_content
      )

      # wait until user clicks "OK"
      # check if ComboBox selected and change view accordingly
      res = nil

      loop do
        # Fill the LogView with file content
        UI.ChangeWidget(Id(:log), :Value, file_content(selected_filename))

        heading = Builtins.sformat(_("System Log (%1)"), selected_filename)
        UI.ChangeWidget(Id(:log), :Label, heading)

        if start_journal?
          res = :journal
          break
        end

        # wait for user input
        res = UI.UserInput

        case res
        when :ok, :cancel then break
        when :custom_file
          # adapt to combo box settings
          new_file = UI.QueryWidget(Id(:custom_file), :Value)
          self.selected_filename = new_file if !new_file.nil?
        else
          Builtins.y2milestone("bad UserInput (%1)", res)
        end
      end

      write_new_filenames if res == :ok
      UI.CloseDialog

      Yast::WFM.CallFunction("journal") if res == :journal

      true
    end

  private

    # Helper method to assess file status.
    #
    # Return one of :ok, :empty, :missing, :no_file, :no_access.
    #
    def file_state(file)
      begin
        File.stat(file)
      rescue Errno::EACCES
        return :no_access
      rescue Errno::ENOENT
        return :missing
      rescue
        nil
      end
      return :no_access if !File.readable?(file)
      return :no_file if !File.file?(file)
      return :empty if !File.size?(file)

      :ok
    end

    # Decide whether to read the log file or to start the 'journal' module instead.
    #
    # If the log can't be read, show some popups indicating the cause.
    #
    # Return true if the 'journal' module should be started.
    #
    def start_journal?
      case file_state(selected_filename)
      when :ok then
        false
      when :empty then
        Yast2::Popup.show(_("The selected log file is empty."))
        false
      when :no_file then
        Yast2::Popup.show(_("The selected item is not a file."))
        false
      when :no_access then
        Yast2::Popup.show(
          _(
            "You do not have permission to read the selected log file.\n\n" \
            "Run this YaST module as user 'root'."
          )
        )
        false
      when :missing then
        res = Yast2::Popup.show(
          _(
            "The selected log file does not exist.\n\n" \
            "Many system components log into the systemd journal.\n" \
            "Do you want to start the YaST module for reading the systemd journal?"
          ),
          buttons: :yes_no,
          focus:   :no
        ) == :yes

        res && Package.Install("yast2-journal")
      end
    end

    def dialog_content
      VBox(
        HSpacing(70), # force width
        HBox(
          HSpacing(1.0),
          ComboBox(
            Id(:custom_file),
            Opt(:editable, :notify, :hstretch),
            "",
            combobox_items
          ),
          HStretch()
        ),
        VSpacing(0.3),
        VWeight(
          1,
          HBox(
            VSpacing(18), # force height
            HSpacing(0.7),
            LogView(
              Id(:log),
              "",
              3, # height
              0
            ), # number of lines to show
            HSpacing(0.7)
          )
        ),
        VSpacing(0.3),
        PushButton(Id(:ok), Label.OKButton),
        VSpacing(0.3)
      )
    end

    def write_new_filenames
      result = []

      to_write = (available_filenames + [selected_filename]).uniq

      # re-build list to get new default correct
      filenames_content.lines.each do |line|
        line.strip!
        result << line if line.empty? || line.start_with?("#")

        line = line[1..-1] if line.start_with?("*")
        to_write.delete(line) # remember that we already write it
        line = "*" + line if selected_filename == line
        result << line
      end
      to_write.each do |line|
        line = "*" + line if selected_filename == line
        result << line
      end

      SCR.Write(
        path(".target.string"),
        filenames_path,
        result.join("\n")
      )
    end

    def filenames_path
      @filenames_path ||= ::File.join(Directory.vardir, "filenames")
    end

    def ensure_filenames_exist
      # Check if the filename list is present
      return if FileUtils.Exists(filenames_path)

      SCR.Execute(
        path(".target.bash"),
        "/bin/cp #{::File.join(Directory.ydatadir, "filenames").shellescape} #{filenames_path.shellescape}"
      )
    end

    attr_writer :selected_filename

    def selected_filename
      return @selected_filename if @selected_filename

      @selected_filename = default_filename
    end

    def file_content(filename)
      # read file content
      result = SCR.Read(path(".target.string"), filename)

      if result
        # replace invalid byte sequences with Unicode "replacement character"
        result.scrub!("�")
        # remove ANSI color escape sequences
        result.remove_ansi_sequences
        # remove remaining ASCII control characters (ASCII 0-31 and 127 (DEL))
        # except new line (LF = 0xa) and carriage return (CR = 0xd)
        result.tr!("\u0000-\u0009\u000b\u000c\u000e-\u001f\u007f", "")
      else
        result = _("File not found.")
      end

      result
    end

    def filenames_list
      @filenames_list ||= filenames_content.lines.each_with_object([]) do |line, result|
        line.strip!
        next if line.empty?
        next if line.start_with?("#")

        line = line[1..-1] if line.start_with?("*")
        result << line
      end
    end

    def available_filenames
      return @available_filenames if @available_filenames

      result = filenames_list + DEFAULT_FILENAMES + [arg_filename]
      @available_filenames = result.uniq.compact
    end

    def arg_filename
      arg = WFM.Args.first
      return arg if arg.is_a?(::String) && !arg.empty?
    end

    def filenames_content
      return @filenames_content if @filenames_content

      ensure_filenames_exist

      # get filename list
      @filenames_content = Convert.to_string(
        SCR.Read(path(".target.string"), filenames_path)
      )

      @filenames_content ||= ""
    end

    def default_filename
      return @default_filename if @default_filename

      return @default_filename = arg_filename if arg_filename

      default_line = filenames_content.lines.find { |l| l.start_with?("*") }

      return @default_filename = available_filenames.first unless default_line

      @default_filename = default_line[1..-1].strip
    end

    def combobox_items
      available_filenames.map do |filename|
        Item(Id(filename), filename, filename == default_filename)
      end
    end
  end
end
