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
# File:	modules/Syslog.ycp
# Package:	yast2
# Summary:	Access to system log
#
# Usage:
#      Syslog::ComplexLog ("", ["-i", "-f", "/tmp/logmessage"]);
#      Syslog::Log ("user was created");
require "yast"

module Yast
  class SyslogClass < Module
    def main

      Yast.import "String"
    end

    # Write a message into system log
    # @param log message
    # @param logger options - see man logger for a list
    # @return result off logger call
    def ComplexLog(message, options)
      options = deep_copy(options)
      options = Builtins.maplist(options) do |o|
        Builtins.sformat("'%1'", String.Quote(o))
      end

      0 ==
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/bin/logger %1 -- %2",
            Builtins.mergestring(options, " "),
            message == "" ?
              "" :
              Ops.add(Ops.add("'", String.Quote(message)), "'")
          )
        )
    end

    # Write a message into system log
    # @param log message
    # @return result off logger call
    def Log(message)
      ComplexLog(message, [])
    end

    publish :function => :ComplexLog, :type => "boolean (string, list <string>)"
    publish :function => :Log, :type => "boolean (string)"
  end

  Syslog = SyslogClass.new
  Syslog.main
end
