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
# File:	modules/Cron.ycp
# Package:	yast2
# Summary:	Read and Write Crontabs
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class CronClass < Module
    def main
      textdomain "base"
    end

    # Read crontab contents
    # @param [String] filename
    # @param [Hash] options (not implemented yet)
    # @return [Array] crontab contents
    def Read(filename, options)
      options = deep_copy(options)
      crontab = Convert.to_list(SCR.Read(path(".cron"), filename, options))
      deep_copy(crontab)
    end


    # Write crontab contents
    # @param [String] filename
    # @param [Array] blocks
    # @return [Boolean] true on success
    def Write(filename, blocks)
      blocks = deep_copy(blocks)
      ret = SCR.Write(path(".cron"), filename, blocks)
      ret
    end








    # Add a simple cron job with comment and env. variables
    # @param [String] comment
    # @param map with environment variables
    # @param [String] command
    # @param [Hash] event event time: dom, dow, hour, minute, month, special
    # @param [String] file path to write cron to
    # @return [Boolean] true on success
    def AddSimple(comment, envs, command, event, file)
      envs = deep_copy(envs)
      event = deep_copy(event)
      cron = {}
      # Comments first
      comments = []
      comments = Builtins.add(comments, comment)
      Ops.set(cron, "comments", comments)

      # Variables
      Ops.set(cron, "envs", envs)

      # Events
      events = []
      Ops.set(event, "command", command)

      events = Builtins.add(events, event)

      Ops.set(cron, "events", events)

      crons = []
      crons = Builtins.add(crons, cron)

      ret = Write(file, crons)
      ret
    end

    publish function: :Read, type: "list (string, map)"
    publish function: :Write, type: "boolean (string, list)"
    publish function: :AddSimple, type: "boolean (string, map, string, map, string)"
  end

  Cron = CronClass.new
  Cron.main
end
