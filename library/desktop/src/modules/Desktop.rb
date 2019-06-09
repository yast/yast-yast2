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
# File:	modules/Desktop.ycp
# Package:	yast2
# Summary:	Handling of .desktop entries
# Author:	Michal Svec <msvec@suse.cz>
#
# $Id$
require "yast"

module Yast
  class DesktopClass < Module
    def main
      Yast.import "UI"
      textdomain "base"
      Yast.import "Map"
      Yast.import "Directory"

      # YaST configuration modules
      @Modules = {}

      #  * YaST configuration groups
      #  *
      #  * <PRE>
      #     Groups=$[
      # 	"Hardware":$[
      # 	    "Icon":"hardware56.png",
      # 	    "Name":"_(\"Hardware\")",
      # 	    "SortKey":"20",
      # 	    "Textdomain":"base",
      # 	    "modules":["cdrom", "hwinfo", ...]
      # 	],
      # 	...
      #    ];
      #  * </PRE>
      @Groups = {}

      # Optional agent path to the desktop files
      @AgentPath = path(".yast2.desktop")

      # Optional language for reading translated entries
      @Language = ""
      @LanguageFull = ""
    end

    def ReadLocalizedKey(fname, keypath, key)
      if key != "Name" && key != "GenericName" && key != "Comment"
        return Convert.to_string(SCR.Read(Builtins.add(keypath, key)))
      end

      ret = ""
      fallback = Convert.to_string(SCR.Read(Builtins.add(keypath, key)))

      # check if there are any translation in .desktop file
      # that is - Name[$lang_code]
      if !@LanguageFull.nil? || @LanguageFull != ""
        newkey = Builtins.sformat("%1[%2]", key, @LanguageFull)
        ret = Convert.to_string(SCR.Read(Builtins.add(keypath, newkey)))
        return ret if !ret.nil? && ret != ""
      end

      if !@Language.nil? || @Language != ""
        newkey = Builtins.sformat("%1[%2]", key, @Language)
        ret = Convert.to_string(SCR.Read(Builtins.add(keypath, newkey)))
        return ret if !ret.nil? && ret != ""
      end

      # no translations in .desktop, check desktop_translations.mo then
      msgid = Builtins.sformat("%1(%2): %3", key, fname, fallback)
      Builtins.y2debug("Looking for key: %1", msgid)
      ret = Builtins.dpgettext(
        "desktop_translations",
        "/usr/share/locale",
        msgid
      )

      # probably untranslated - return english name
      return fallback if ret == msgid

      ret
    end

    # Internal function: set up the language variables.
    def ReadLanguage
      # read language
      @LanguageFull = ""
      @Language = UI.GetLanguage(true)
      if Builtins.regexpmatch(@Language, "(.*_[^.]*)\\.?.*") # matches: ll_TT ll_TT.UTF-8
        @LanguageFull = Builtins.regexpsub(@Language, "(.*_[^.]*)\\.?.*", "\\1")
      end
      if Builtins.regexpmatch(@Language, "(.*)_")
        @Language = Builtins.regexpsub(@Language, "(.*)_", "\\1")
      end
      Builtins.y2debug("LanguageFull=%1", @LanguageFull)
      Builtins.y2debug("Language=%1", @Language)

      nil
    end

    # Read module and group data from desktop files
    # @param [Array<String>] Values list of values to be parsed (empty to read all)
    def Read(values_to_parse)
      values_to_parse = deep_copy(values_to_parse)

      ReadLanguage()

      # read groups
      menus = SCR.Read(path(".anyxml"), "/etc/xdg/menus/yast-settings.menu")
      menus["Menu"][0]["Menu"].each_with_index do |menu, index|
        filename = menu["Directory"][0]["content"]
        file = "#{Directory.directoriesdir}/#{filename}"
        # Only one category supported, for the sake of clarity
        category = menu["Include"][0]["Category"][0]["content"]
        filepath = path(".yast2.groups.v") + file + path(".\"Desktop Entry\"")
        filemap = {}
        filemap["Icon"] = SCR.Read(filepath + "Icon")
        filemap["Hidden"] = SCR.Read(filepath + "Hidden")
        filemap["Name"] = ReadLocalizedKey(filename, filepath, "Name")
        # Now SortKey isn't needed in directory file, because xml defines order already
        filemap["SortKey"] = index.to_s
        filemap["modules"] = []
        @Groups[category] = filemap
      end
      Builtins.y2debug("Groups=%1", @Groups)

      # read modules
      ps = Builtins.add(@AgentPath, "s")
      files = SCR.Dir(ps)
      files.each do |file|
        filepath = @AgentPath + path(".v") + file + path(".\"Desktop Entry\"")
        #Very quick sanity check if the file contains the needed categories
        next unless SCR.Read(filepath + "Categories")&.include? "X-SuSE-YaST-"

        filename = File.basename(file, ".desktop")
        values = SCR.Dir(filepath)
        values = deep_copy(values_to_parse) unless values_to_parse&.empty?

        filemap = {}
        values.each do |value|
          ret = ReadLocalizedKey(filename, filepath, value)
          filemap[value] = ret unless ret&.empty?
        end
        group = ""
        filemap["Categories"].split(";").each do |cat|
            group = cat if @Groups[cat]
        end

        @Modules[filename] = filemap
        @Groups[group]["modules"] << filename unless group&.empty?
      end
      Builtins.y2debug("Groups=%1", @Groups)
      Builtins.y2debug("Modules=%1", @Modules)

      nil
    end

    def Translate(key)
      if Builtins.regexpmatch(key, "_\\(\"(.*)\"\\)") == true
        ke = Builtins.regexpsub(key, "_\\(\"(.*)\"\\)", "\\1")
        key = Builtins.eval(ke)
        Builtins.y2milestone("%1 -> %2", ke, key)
      end
      key
    end

    def CreateList(m)
      m = deep_copy(m)
      keys = Map.Keys(m)
      keys = Builtins.sort(keys) do |x, y|
        Ops.less_than(
          Ops.get_string(m, [x, "SortKey"], ""),
          Ops.get_string(m, [y, "SortKey"], "")
        )
      end

      keys = Builtins.filter(keys) do |key|
        Ops.get_string(m, [key, "Hidden"], "false") != "true"
      end

      Builtins.y2debug("keys=%1", keys)

      Builtins.maplist(keys) do |name|
        Item(Id(name), Translate(Ops.get_string(m, [name, "Name"], "???")))
      end
    end

    def GroupList
      CreateList(@Groups)
    end

    def ModuleList(group)
      mods = Ops.get_list(@Groups, [group, "modules"], [])
      l = []

      # support sort keys: #36466
      mods = Builtins.sort(mods) do |x, y|
        Ops.less_than(
          Ops.get_string(
            @Modules,
            [x, "X-SuSE-YaST-SortKey"],
            Ops.get_string(@Modules, [x, "GenericName"], "")
          ),
          Ops.get_string(
            @Modules,
            [y, "X-SuSE-YaST-SortKey"],
            Ops.get_string(@Modules, [y, "GenericName"], "")
          )
        )
      end

      Builtins.foreach(mods) do |m|
        if Builtins.haskey(@Modules, m) &&
            Ops.get_string(@Modules, [m, "Hidden"], "false") != "true"
          l = Builtins.add(
            l,
            Item(Id(m), Ops.get_string(@Modules, [m, "GenericName"], "???"))
          )
        end
      end

      # y2debug too costly: y2debug("%1", m);
      deep_copy(l)
    end

    def MakeAutostartMap(exec, args)
      args = deep_copy(args)
      {
        "Encoding"         => "UTF-8",
        "Name"             => exec,
        "Exec"             => exec,
        "X-SuSE-Autostart" => Ops.add(
          Ops.add(exec, " "),
          Builtins.mergestring(args, " ")
        ),
        "Hidden"           => "true",
        "Icon"             => exec,
        "Type"             => "Application"
      }
    end

    # Runs a program by writing a special desktop file.
    # Works with KDE and GNOME.
    # Useful for kinternet, see bug 37864#c17
    # @param [String] exec program to exec (basename)
    def RunViaDesktop(exec, args)
      args = deep_copy(args)
      content = "[KDE Desktop Entry]\n"
      Builtins.foreach(MakeAutostartMap(exec, args)) do |key, value|
        content = Ops.add(content, Builtins.sformat("%1=%2\n", key, value))
      end
      dir = "/var/lib/Desktop"
      SCR.Write(
        path(".target.string"),
        Builtins.sformat("%1/yast2-run-%2.desktop", dir, exec),
        content
      )

      nil
    end

    # Parses the a .desktop file it gets as a parameter without trying to use
    # already cached information or agent to access all desktop files. This is
    # optimized version to be used for rapid start of modules.
    # Desktop file is placed in a special directory (/usr/share/applications/YaST2).
    # Parameter file is relative to that directory without ".desktop" suffix.
    # Warning: There are no desktop files in inst-sys.
    #
    # @param [String] file desktop file name
    # @return [Hash] filled with data, or nil
    #
    # @example
    #	// Opens /usr/share/applications/YaST2/lan.desktop
    #	map<string,string> description = Desktop::ParseSingleDesktopFile ("lan");
    #	Wizard::SetDialogTitle (description["Name"]:_("None));
    def ParseSingleDesktopFile(file)
      filename = Builtins.sformat("%1/%2.desktop", Directory.desktopdir, file)
      # Do not use .yast2.desktop.v.$filename, because ini-agent reads
      # all the desktop files anyway which is wasteful for setting one icon.
      # The config is adapted from .yast2.desktop.
      SCR.RegisterAgent(
        path(".yast2.desktop1"),
        term(
          :ag_ini,
          term(
            :IniAgent,
            filename,

            "options"  => ["read_only"], # rw works but not needed
            "comments" => ["^[ \t]*#.*", "\\{[^}]*\\}", "^[ \t]*$"],
            "sections" => [
              {
                "begin" => [
                  "^[ \t]*\\[[ \t]*(.*[^ \t])[ \t]*\\][ \t]*",
                  "[%s]"
                ]
              }
            ],
            "params"   => [
              {
                "match" => [
                  "^[ \t]*([^=]*[^ \t=])[ \t]*=[ \t]*(.*[^ \t]|)[ \t]*$",
                  "%s=%s"
                ]
              }
            ]

          )
        )
      )

      # non-existent file requested
      if SCR.Dir(path(".yast2.desktop1.v.\"Desktop Entry\"")).nil?
        Builtins.y2error("Unknown desktop file: %1", file)
        SCR.UnregisterAgent(path(".yast2.desktop1"))
        return nil
      end

      # we need localized keys
      ReadLanguage()

      result = {
        "Icon"        => Convert.to_string(
          SCR.Read(path(".yast2.desktop1.v.\"Desktop Entry\".Icon"))
        ),
        "Name"        => ReadLocalizedKey(
          Ops.add(file, ".desktop"),
          path(".yast2.desktop1.v.\"Desktop Entry\""),
          "Name"
        ),
        "GenericName" => ReadLocalizedKey(
          Ops.add(file, ".desktop"),
          path(".yast2.desktop1.v.\"Desktop Entry\""),
          "GenericName"
        ),
        "Comment"     => ReadLocalizedKey(
          Ops.add(file, ".desktop"),
          path(".yast2.desktop1.v.\"Desktop Entry\""),
          "Comment"
        )
      }

      SCR.UnregisterAgent(path(".yast2.desktop1"))

      deep_copy(result)
    end

    publish variable: :Modules, type: "map <string, map>"
    publish variable: :Groups, type: "map <string, map>"
    publish variable: :AgentPath, type: "path"
    publish function: :Read, type: "void (list <string>)"
    publish function: :Translate, type: "string (string)"
    publish function: :GroupList, type: "list <term> ()"
    publish function: :ModuleList, type: "list <term> (string)"
    publish function: :RunViaDesktop, type: "void (string, list <string>)"
    publish function: :ParseSingleDesktopFile, type: "map <string, string> (string)"
  end

  Desktop = DesktopClass.new
  Desktop.main
end
