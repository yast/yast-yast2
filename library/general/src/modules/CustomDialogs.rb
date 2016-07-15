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
# File:	modules/CustomDialogs.ycp
# Module:	yast2
# Summary:	Installation mode
# Authors:	Klaus Kaempf <kkaempf@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class CustomDialogsClass < Module
    def main
    end

    def load_file_locale(patterns, file_path, language)
      patterns = deep_copy(patterns)
      i = 0
      while Ops.less_than(i, Builtins.size(patterns))
        p = Ops.get(patterns, i, "")
        tmp = Ops.add(Ops.add(file_path, "/"), p)
        if !Builtins.issubstring(p, "%")
          Builtins.y2debug("no pattern")
          Builtins.y2debug("checking for %1", tmp)
          text = Convert.to_string(SCR.Read(path(".target.string"), [tmp, ""]))

          break if text != ""

          i = Ops.add(i, 1)
          next
        end
        file = Builtins.sformat(tmp, language)
        Builtins.y2debug("checking for %1", file)
        text = Convert.to_string(SCR.Read(path(".target.string"), [file, ""]))
        break if text != ""

        file = Builtins.sformat(tmp, Builtins.substring(language, 0, 2))
        Builtins.y2debug("checking for %1", file)
        text = Convert.to_string(SCR.Read(path(".target.string"), [file, ""]))
        break if text != ""

        file = Builtins.sformat(tmp, "en")
        Builtins.y2debug("checking for %1", file)
        text = Convert.to_string(SCR.Read(path(".target.string"), [file, ""]))
        break if text != ""
        i = Ops.add(i, 1)
      end
      { "text" => text, "file" => file }
    end

    publish function: :load_file_locale, type: "map (list <string>, string, string)"
  end

  CustomDialogs = CustomDialogsClass.new
  CustomDialogs.main
end
