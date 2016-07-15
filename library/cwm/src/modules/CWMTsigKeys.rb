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
# File:	modules/CWMTsigKeys.ycp
# Package:	Common widget manipulation, TSIG keys management widget
# Summary:	Routines for management of TSIG keys
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class CWMTsigKeysClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "String"

      # private variables

      # Currently configured TSIG keys
      # Each entry is a map with keys "filename" and "key"
      @tsig_keys = []

      # Filenames of the files that contained deleted TSIG keys
      @deleted_tsig_keys = []

      # Filenames of the new added TSIG keys
      @new_tsig_keys = []
    end

    # private functions

    # Redraw the table of DDNS keys
    def DdnsKeysWidgetRedraw
      items = Builtins.maplist(@tsig_keys) do |k|
        Item(
          Id(Ops.get(k, "key", "")),
          Ops.get(k, "key", ""),
          Ops.get(k, "filename", "")
        )
      end
      UI.ChangeWidget(
        Id("_cwm_delete_key"),
        :Enabled,
        Ops.greater_than(Builtins.size(items), 0)
      )
      UI.ChangeWidget(Id("_cwm_key_listing_table"), :Items, items)
      UI.SetFocus(Id("_cwm_key_listing_table"))

      nil
    end

    # Get the file that contains the specified key
    # @param [String] key string key ID
    # @return [String] file containing the key
    def Key2File(key)
      filename = ""
      Builtins.find(@tsig_keys) do |k|
        if Ops.get(k, "key") == key
          filename = Ops.get(k, "filename", "")
          next true
        end
        false
      end
      Builtins.y2milestone("Key: %1, File: %2", key, filename)
      filename
    end

    # Remove file with all TSIG keys it contains
    # @param [String] filename string filename of the file with the TSIG keys
    def RemoveTSIGKeyFile(filename)
      @new_tsig_keys = Builtins.filter(@new_tsig_keys) { |f| f != filename }
      @deleted_tsig_keys = Builtins.add(@deleted_tsig_keys, filename)
      @tsig_keys = Builtins.filter(@tsig_keys) do |k|
        Ops.get(k, "filename", "") != filename
      end

      nil
    end

    # Remove file containing specified TSIG key
    # @param [String] key string key ID
    def RemoveTSIGKey(key)
      filename = Key2File(key)
      RemoveTSIGKeyFile(filename)

      nil
    end

    # Add new file with TSIG key
    # @param [String] filename string filename of the file with the TSIG key
    def AddTSIGKeyFile(filename)
      @deleted_tsig_keys = Builtins.filter(@deleted_tsig_keys) do |f|
        f != filename
      end
      @new_tsig_keys = Builtins.add(@new_tsig_keys, filename)
      keys = AnalyzeTSIGKeyFile(filename)
      Builtins.foreach(keys) do |k|
        @tsig_keys = Builtins.add(
          @tsig_keys,
          "key" => k, "filename" => filename
        )
      end

      nil
    end

    # public routines related to TSIG keys management

    # Remove leading and trailibg blanks and quotes from file name
    # @param [String] filename string file name
    # @return file name without leading/trailing quotes and blanks
    def NormalizeFilename(filename)
      while filename != "" &&
          (Builtins.substring(filename, 0, 1) == " " ||
            Builtins.substring(filename, 0, 1) == "\"")
        filename = Builtins.substring(filename, 1)
      end
      while filename != "" &&
          (Builtins.substring(
            filename,
            Ops.subtract(Builtins.size(filename), 1),
            1
          ) == " " ||
            Builtins.substring(
              filename,
              Ops.subtract(Builtins.size(filename), 1),
              1
            ) == "\"")
        filename = Builtins.substring(
          filename,
          0,
          Ops.subtract(Builtins.size(filename), 1)
        )
      end
      filename
    end

    # Analyze file that may contain TSIG keys
    # @param [String] filename string filename of the file that may contain TSIG keys
    # @return a list of all TSIG key IDs in the file
    def AnalyzeTSIGKeyFile(filename)
      filename = NormalizeFilename(filename)
      contents = Convert.to_string(SCR.Read(path(".target.string"), filename))
      if contents.nil?
        Builtins.y2warning("Unable to read file with TSIG keys: %1", filename)
        return []
      end
      ret = []
      parts = Builtins.splitstring(contents, "{}")
      Builtins.foreach(parts) do |p|
        if Builtins.regexpmatch(p, ".*key[[:space:]]+[^[:space:]}{;]+\\.* $")
          ret = Builtins.add(
            ret,
            Builtins.regexpsub(
              p,
              ".*key[[:space:]]+([^[:space:]}{;]+)\\.* $",
              "\\1"
            )
          )
        end
      end
      Builtins.y2milestone("File: %1, Keys: %2", filename, ret)
      deep_copy(ret)
    end

    # Remove all 3 files holding the TSIG key data
    # @param [String] main string filename of the main file
    def DeleteTSIGKeyFromDisk(main)
      keys = AnalyzeTSIGKeyFile(main)
      Builtins.y2milestone("Removing file %1, found keys: %2", main, keys)
      Builtins.foreach(keys) do |k|
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("rm -rf /etc/named.d/K%1\\.* ", Builtins.tolower(k))
        )
      end
      SCR.Execute(path(".target.remove"), main)

      nil
    end

    # Transformate the list of files to the list of TSIG key description maps
    # @param [Array<String>] filenames a list of file names of the TSIG keys
    # @return a list of TSIG key describing maps
    def Files2KeyMaps(filenames)
      filenames = deep_copy(filenames)
      tmpret = Builtins.maplist(filenames) do |f|
        keys = AnalyzeTSIGKeyFile(f)
        Builtins.maplist(keys) { |k| { "filename" => f, "key" => k } }
      end
      ret = Builtins.flatten(tmpret)
      Builtins.y2milestone("Files: %1, Keys: %2", filenames, ret)
      deep_copy(ret)
    end

    # Get all TSIG keys that present in the files
    # @param filename a list of file names
    # @return a list of all TSIG key IDs
    def Files2Keys(filenames)
      filenames = deep_copy(filenames)
      keys = Files2KeyMaps(filenames)
      ret = Builtins.maplist(keys) { |k| Ops.get(k, "key", "") }
      Builtins.y2milestone("Files: %1, Keys: %2", filenames, ret)
      deep_copy(ret)
    end

    # widget related functions

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def Init(widget, _key)
      widget = deep_copy(widget)
      get_keys_info = Convert.convert(
        Ops.get(widget, "get_keys_info"),
        from: "any",
        to:   "map <string, any> ()"
      )
      info = get_keys_info.call
      @tsig_keys = Ops.get_list(info, "tsig_keys", [])
      @deleted_tsig_keys = Ops.get_list(info, "removed_files", [])
      @new_tsig_keys = Ops.get_list(info, "new_files", [])
      if !Builtins.haskey(info, "tsig_keys")
        files = Ops.get_list(info, "key_files", [])
        @tsig_keys = Files2KeyMaps(files)
      end
      initial_path = "/etc/named.d/"
      UI.ChangeWidget(Id("_cwm_existing_key_file"), :Value, initial_path)
      UI.ChangeWidget(Id("_cwm_new_key_file"), :Value, initial_path)
      UI.ChangeWidget(
        Id("_cwm_new_key_id"),
        :ValidChars,
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
      )
      DdnsKeysWidgetRedraw()

      nil
    end

    # Handle function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def Handle(widget, _key, event)
      widget = deep_copy(widget)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      existing_filename = Convert.to_string(
        UI.QueryWidget(Id("_cwm_existing_key_file"), :Value)
      )
      new_filename = Convert.to_string(
        UI.QueryWidget(Id("_cwm_new_key_file"), :Value)
      )
      if ret == "_cwm_delete_key"
        key2 = Convert.to_string(
          UI.QueryWidget(Id("_cwm_key_listing_table"), :CurrentItem)
        )
        delete_filename = Key2File(key2)
        if Ops.get(widget, "list_used_keys") &&
            Ops.is(Ops.get(widget, "list_used_keys"), "list <string> ()")
          lister = Convert.convert(
            Ops.get(widget, "list_used_keys"),
            from: "any",
            to:   "list <string> ()"
          )
          used_keys = lister.call
          keys_to_delete = AnalyzeTSIGKeyFile(delete_filename)
          keys_to_delete = Builtins.filter(keys_to_delete) do |k|
            Builtins.contains(used_keys, k)
          end
          if Ops.greater_than(Builtins.size(keys_to_delete), 0)
            # popup message
            message = _(
              "The selected TSIG key cannot be deleted,\n" \
                "because it is in use.\n" \
                "Stop using it in the configuration first."
            )
            # popup title
            Popup.AnyMessage(_("Cannot delete TSIG key."), message)
            return nil
          end
        end
        RemoveTSIGKeyFile(delete_filename)
      elsif ret == "_cwm_browse_existing_key_file"
        existing_filename = UI.AskForExistingFile(
          existing_filename,
          "",
          # popup headline
          _("Select File with the Authentication Key")
        )
        if !existing_filename.nil?
          UI.ChangeWidget(
            Id("_cwm_existing_key_file"),
            :Value,
            existing_filename
          )
        end
        return nil
      elsif ret == "_cwm_browse_new_key_file"
        new_filename = UI.AskForSaveFileName(
          new_filename,
          "",
          # popup headline
          _("Select File for the Authentication Key")
        )
        if !new_filename.nil?
          UI.ChangeWidget(Id("_cwm_new_key_file"), :Value, new_filename)
        end
        return nil
      elsif ret == "_cwm_generate_key"
        if !UI.WidgetExists(Id("_cwm_new_key_file"))
          Builtins.y2error("No such UI widget: %1", "_cwm_new_key_file")
          return nil
        end

        key2 = Convert.to_string(UI.QueryWidget(Id("_cwm_new_key_id"), :Value))
        stat = Convert.to_map(SCR.Read(path(".target.stat"), new_filename))

        if Builtins.size(stat) != 0
          if Ops.get_boolean(stat, "isdir", false)
            UI.SetFocus(Id("_cwm_new_key_file"))
            Report.Error(
              # error report
              _("Specified filename is an existing directory.")
            )
            return nil
          end
          # yes-no popup
          return nil unless Popup.YesNo(_("Specified file exists. Rewrite it?"))

          DeleteTSIGKeyFromDisk(new_filename)
          RemoveTSIGKeyFile(new_filename)
        end
        if key2.nil? || key2 == ""
          UI.SetFocus(Id("_cwm_new_key_id"))
          # error report
          Popup.Error(_("The TSIG key ID was not specified."))
          return nil
        end
        # specified key exists
        if Key2File(key2) != ""
          # yes-no popup
          if !Popup.YesNo(
            _("The key with the specified ID exists and is used.\nRemove it?")
          )
            return nil
          else
            remove_file = Key2File(key2)
            DeleteTSIGKeyFromDisk(remove_file)
            RemoveTSIGKeyFile(remove_file)
          end
        end
        # specified key is present on the disk, but not used
        if 0 ==
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "ls /etc/named.d/K%1\\.*",
                Builtins.tolower(key2)
              )
            )
          # yes-no popup
          if Popup.YesNo(
            _(
              "A key with the specified ID was found\non your disk. Remove it?"
            )
          )
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "rm -rf `ls /etc/named.d/K%1\\.*`",
                Builtins.tolower(key2)
              )
            )
            files = Convert.convert(
              SCR.Read(path(".target.dir"), "/etc/named.d"),
              from: "any",
              to:   "list <string>"
            )
            Builtins.foreach(files) do |f|
              if Builtins.contains(AnalyzeTSIGKeyFile(f), key2)
                DeleteTSIGKeyFromDisk(f)
              end
            end
          end
        end

        # yes-no popup
        return nil if !Popup.YesNo(_("The key will be created now. Continue?"))
        SCR.Execute(
          path(".target.bash"),
          "test -d /etc/named.d || mkdir /etc/named.d"
        )
        gen_command = Builtins.sformat(
          "/usr/bin/genDDNSkey --force  -f '%1' -n '%2' -d /etc/named.d",
          String.Quote(new_filename),
          String.Quote(key2)
        )
        Builtins.y2milestone("Running %1", gen_command)
        gen_ret = Convert.to_integer(
          SCR.Execute(path(".target.bash"), gen_command)
        )
        if gen_ret != 0
          # error report
          Report.Error(_("Creating the TSIG key failed."))
          return nil
        end
        ret = "_cwm_add_key"
        existing_filename = new_filename
      end
      if ret == "_cwm_add_key"
        stat = Convert.to_map(SCR.Read(path(".target.stat"), new_filename))
        if Builtins.size(stat) == 0
          # message popup
          Popup.Message(_("The specified file does not exist."))
          return nil
        end
        keys = AnalyzeTSIGKeyFile(existing_filename)
        if Builtins.size(keys) == 0
          # message popup
          Popup.Message(_("The specified file does not contain any TSIG key."))
          return nil
        end
        coliding_files = Builtins.maplist(keys) { |k| Key2File(k) }
        coliding_files = Builtins.filter(Builtins.toset(coliding_files)) do |f|
          f != ""
        end
        if Ops.greater_than(Builtins.size(coliding_files), 0)
          # yes-no popup
          if !Popup.YesNo(
            _(
              "The specified file contains a TSIG key with the same\n" \
                "identifier as some of already present keys.\n" \
                "Old keys will be removed. Continue?"
            )
          )
            return nil
          else
            Builtins.foreach(coliding_files) { |f| RemoveTSIGKeyFile(f) }
          end
        end
        AddTSIGKeyFile(existing_filename)
      end
      DdnsKeysWidgetRedraw()
      nil
    end

    # Store function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def Store(widget, _key, _event)
      widget = deep_copy(widget)
      set_info = Convert.convert(
        Ops.get(widget, "set_keys_info"),
        from: "any",
        to:   "void (map <string, any>)"
      )
      info = {
        "removed_files" => @deleted_tsig_keys,
        "new_files"     => @new_tsig_keys,
        "tsig_keys"     => @tsig_keys,
        "key_files"     => Builtins.toset(Builtins.maplist(@tsig_keys) do |k|
          Ops.get(k, "filename", "")
        end)
      }
      set_info.call(info)

      nil
    end

    # Store function of the widget
    # @param map widget a widget description map
    # @param [String] key strnig the widget key
    # @param event map that caused widget data storing/**
    # Init function of the widget
    # @param [String] key strnig the widget key
    def InitWrapper(key)
      Init(CWM.GetProcessedWidget, key)

      nil
    end

    # Handle function of the widget
    # @param map widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def HandleWrapper(key, event)
      event = deep_copy(event)
      Handle(CWM.GetProcessedWidget, key, event)
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def StoreWrapper(key, event)
      event = deep_copy(event)
      Store(CWM.GetProcessedWidget, key, event)

      nil
    end

    # Get the widget description map
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    # "get_keys_info" : map<string,any>() -- function for getting information
    #          about TSIG keys. Return map should contain:
    #           - "removed_files" : list<string> -- files that have been removed
    #           - "new_files" : list<string> -- files that have been added
    #           - "tsig_keys" : list<map<string,string>> -- list of all TSIG keys
    #           - "key_files" : list<string> -- list of all files that may contain
    #                       TSIG keys
    #           Either "tsig_keys" or "key_files" are mandatory
    # "set_keys_info" : void (map<string,any>) -- function for storing information
    #          about keys. Map has keys:
    #           - "removed_files" : list<string> -- files that have been removed
    #           - "new_files" : list<string> -- files that have been added
    #           - "tsig_keys" : list<map<string,string>> -- list of all TSIG keys
    #           - "key_files" : list<string> -- list of all files that contain
    #                       TSIG keys
    #
    # Additional settings:
    # - "list_used_keys" : list<string>() -- function for getting the list of
    #          used TSIG keys. The list is used to prevent used TSIG keys from
    #          being deleted. If not present, all keys may get deleted.
    # - "help" : string -- help to the whole widget. If not specified, generic help
    #          is used (button labels are patched correctly)
    # </pre>
    # @return a map the widget description map
    def CreateWidget(settings)
      settings = deep_copy(settings)
      # tsig keys management dialog help 1/4
      help = _(
        "<p><big><b>TSIG Key Management</b></big><br>\nUse this dialog to manage the TSIG keys.</p>\n"
      ) +
        # tsig keys management dialog help 2/4
        _(
          "<p><big><b>Adding an Existing TSIG Key</b></big><br>\n" \
            "To add an already created TSIG key, select a <b>Filename</b> of the file\n" \
            "containing the key and click <b>Add</b>.</p>\n"
        ) +
        # tsig keys management dialog help 3/4
        _(
          "<p><big><b>Creating a New TSIG Key</b></big><br>\n" \
            "To create a new TSIG key, set the <b>Filename</b> of the file in which to\n" \
            "create the key and the <b>Key ID</b> to identify the key then click\n" \
            "<b>Generate</b>.</p>\n"
        ) +
        # tsig keys management dialog help 4/4
        _(
          "<p><big><b>Removing a TSIG Key</b></big><br>\n" \
            "To remove a configured TSIG key, select it and click <b>Delete</b>.\n" \
            "All keys in the same file are deleted.\n" \
            "If a TSIG key is in use in the configuration\n" \
            "of the server, it cannot be deleted. The server must stop using it\n" \
            "in the configuration first.</p>\n"
        )

      add_existing = VSquash(
        # Frame label - adding a created server key
        Frame(
          _("Add an Existing TSIG Key"),
          HBox(
            HWeight(
              9,
              HBox(
                HWeight(
                  7,
                  HBox(
                    InputField(
                      Id("_cwm_existing_key_file"),
                      Opt(:hstretch),
                      # text entry
                      Label.FileName
                    )
                  )
                ),
                HWeight(
                  2,
                  HBox(
                    VBox(
                      Label(" "),
                      PushButton(
                        Id("_cwm_browse_existing_key_file"),
                        Label.BrowseButton
                      )
                    )
                  )
                )
              )
            ),
            HWeight(
              2,
              Bottom(
                VSquash(
                  PushButton(
                    Id("_cwm_add_key"),
                    Opt(:hstretch),
                    Label.AddButton
                  )
                )
              )
            )
          )
        )
      )

      create_new = VSquash(
        # Frame label - creating a new server key
        Frame(
          _("Create a New TSIG Key"),
          HBox(
            HWeight(
              9,
              HBox(
                HWeight(
                  7,
                  HBox(
                    # text entry
                    InputField(
                      Id("_cwm_new_key_id"),
                      Opt(:hstretch),
                      _("&Key ID")
                    ),
                    # text entry
                    InputField(
                      Id("_cwm_new_key_file"),
                      Opt(:hstretch),
                      Label.FileName
                    )
                  )
                ),
                HWeight(
                  2,
                  HBox(
                    VBox(
                      Label(" "),
                      PushButton(
                        Id("_cwm_browse_new_key_file"),
                        Label.BrowseButton
                      )
                    )
                  )
                )
              )
            ),
            HWeight(
              2,
              Bottom(
                # push button
                VSquash(
                  PushButton(
                    Id("_cwm_generate_key"),
                    Opt(:hstretch),
                    _("&Generate")
                  )
                )
              )
            )
          )
        )
      )

      current_keys = VBox(
        VSpacing(0.5),
        # Table header - in fact label
        Left(Label(_("Current TSIG Keys"))),
        HBox(
          HWeight(
            9,
            Table(
              Id("_cwm_key_listing_table"),
              Header(
                # Table header item - DNS key listing
                _("Key ID"),
                # Table header item - DNS key listing
                _("Filename")
              ),
              []
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(
                PushButton(
                  Id("_cwm_delete_key"),
                  Opt(:hstretch),
                  Label.DeleteButton
                )
              ),
              VStretch()
            )
          )
        )
      )

      contents = VBox(add_existing, create_new, current_keys)

      ret = Convert.convert(
        Builtins.union(
          {
            "widget"        => :custom,
            "custom_widget" => contents,
            "help"          => help,
            "init"          => fun_ref(method(:InitWrapper), "void (string)"),
            "store"         => fun_ref(
              method(:StoreWrapper),
              "void (string, map)"
            ),
            "handle"        => fun_ref(
              method(:HandleWrapper),
              "symbol (string, map)"
            )
          },
          settings
        ),
        from: "map",
        to:   "map <string, any>"
      )

      deep_copy(ret)
    end

    publish function: :AnalyzeTSIGKeyFile, type: "list <string> (string)"
    publish function: :NormalizeFilename, type: "string (string)"
    publish function: :DeleteTSIGKeyFromDisk, type: "void (string)"
    publish function: :Files2KeyMaps, type: "list <map <string, string>> (list <string>)"
    publish function: :Files2Keys, type: "list <string> (list <string>)"
    publish function: :Init, type: "void (map <string, any>, string)"
    publish function: :Handle, type: "symbol (map <string, any>, string, map)"
    publish function: :Store, type: "void (map <string, any>, string, map)"
    publish function: :InitWrapper, type: "void (string)"
    publish function: :HandleWrapper, type: "symbol (string, map)"
    publish function: :StoreWrapper, type: "void (string, map)"
    publish function: :CreateWidget, type: "map <string, any> (map <string, any>)"
  end

  CWMTsigKeys = CWMTsigKeysClass.new
  CWMTsigKeys.main
end
