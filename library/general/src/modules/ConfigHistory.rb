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

# File:	modules/ConfigHistory.ycp
# Package:	Maintain history of configuration files
# Summary:	ConfigHistory settings, input and output functions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id: ConfigHistory.ycp 41350 2007-10-10 16:59:00Z dfiser $
#
# Routines for tracking configuration files in a subversion repository
#
# Use:
# - at your module start, call ConfigHistory::Init(); which will initialize
#   the repo if needed and also commits any uncommitted changes
# - at the module finish, call ConfigHistory::CommitChanges("module name");
#   which will commit the changes made to SVN with appropriate comment
#   mentioning the module name in the log
# - to ensure all configuration files are in SVN after initialization, call
#   ConfigHistory::InitFiles(["file1", "file2"]) immediatelly after calling
#   Init(); which will ensure the changes made are tracked during the first
#   run as well
#
# See also /etc/sysconfig/yast2, variables STORE_CONFIG_IN_SUBVERSION and
# SUBVERSION_ADD_DIRS_RECURSIVE
require "yast"

module Yast
  class ConfigHistoryClass < Module
    include Yast::Logger

    def main
      textdomain "config-history"

      # Location of SVN repo
      @history_location = "/var/lib/YaST2/config-history"

      # Location of timestamp for detecting changed files out of version control
      @changes_timestamp = "/var/lib/YaST2/config-history-timestamp"

      # Directories to put under version control
      @log_directories = ["/etc"]

      # Is the SVN history active?
      @use_svn = nil

      # Always have whole subtree in SVN, not only files changed by YaST
      @store_whole_subtree = nil

      # Count of nested transactions (module calling another module)
      @nested_transactions = 0

      # If true, force commit at the end of initialization/finalization
      @commit_needed = false
    end

    # Is the SVN history in use?
    # @return [Boolean] true to log to SVN
    def UseSvn
      if @use_svn == nil
        @use_svn = Convert.to_string(
          SCR.Read(path(".sysconfig.yast2.STORE_CONFIG_IN_SUBVERSION"))
        ) == "yes"
        log.info "Using SVN for configuration files: #{@use_svn}"
      end
      @use_svn
    end

    def Recursive
      if @store_whole_subtree == nil
        @store_whole_subtree = Convert.to_string(
          SCR.Read(path(".sysconfig.yast2.SUBVERSION_ADD_DIRS_RECURSIVE"))
        ) == "yes"
        log.info "Automatically store whole subtree: #{@store_whole_subtree}"
      end
      @store_whole_subtree
    end

    # Initialize a SVN repository for config files in /var/lib/YaST2
    # @return [Boolean] true on success, false otherwise
    def InitSvnRepository
      log.info "Initializing repo at #{@history_location}"
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("svnadmin create %1", @history_location)
        )
      )
      if Ops.get_integer(out, "exit", -1) != 0
        log.error "Failed to initialize SVN repository: #{Ops.get_string(out, "stderr", "")}"
        return false
      end
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "chown -R root:root %1; chmod -R g= %1; chmod -R o= %1",
            @history_location
          )
        )
      )
      if Ops.get_integer(out, "exit", -1) != 0
        log.error "Failed to set svn repo permissions: #{Ops.get_string(out, "stderr", "")}"
        return false
      end
      log.info "Repo initialized"
      true
    end

    # Check the presence of SVN repo for storing changes
    # @return [Boolean] true if repo exists
    def CheckSvnRepository
      log.info "Checking repo presence"
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("test -d %1", @history_location)
        )
      )
      ret = Ops.get_integer(out, "exit", -1) == 0
      log.info "Repo found: #{ret}"
      ret
    end

    # Check whether repo has been deployed to the filesystem
    # @return [Boolean] true if yes (/.svn exists), false otherwise
    def CheckRepoLinked
      log.info "Checking whether repo is linked to root directory"
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("test -d %1", "/.svn")
        )
      )
      ret = Ops.get_integer(out, "exit", -1) == 0
      log.info "Repo linked: #{ret}"
      ret
    end

    # Initialize predefined directories for SVN
    # @param [Boolean] recursive boolean true to add whole directories incl. subtree,
    #        false to add directory itself only
    # @return [Boolean] true on success, false on failure
    def InitDirectories(recursive)
      log.info "Linking system with the repository; recursive: #{recursive}"
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("svn co file://%1 /", @history_location)
        )
      )
      if Ops.get_integer(out, "exit", -1) != 0
        log.error "svn check out to root failed: #{Ops.get_string(out, "stderr", "")}"
        return false
      end
      success = true
      Builtins.foreach(@log_directories) do |dir|
        log.info "Initializing directory #{dir}"
        params = recursive ? "" : "-N"
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("cd / ; svn add %2 %1", dir, params)
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          success = false
          log.error "Failed to add directory #{dir}: #{Ops.get_string(out, "stderr", "")}"
        end
      end
      return false if !success
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "cd / ; svn ci -m 'Initial check-in'"
        )
      )
      if Ops.get_integer(out, "exit", -1) != 0
        log.error "Initial check-in to repo failed: #{Ops.get_string(out, "stderr", "")}"
        return false
      end
      log.info "Initial check-in succeeded"
      true
    end

    # Check for files in version control which had been changed but not committed
    # @return [Boolean] true on success
    def CheckUncommitedChanges
      success = true
      Builtins.foreach(@log_directories) do |dir|
        log.info "Checking for uncommitted changes in #{dir}"
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("cd %1; svn st |grep '^M'", dir)
          )
        )
        if Ops.get_integer(out, "exit", -1) == 1 && !@commit_needed
          log.info "No uncommitted change detected"
        else
          out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "cd %1; svn ci -m 'Commit remaining changes before running YaST'",
                dir
              )
            )
          )
          if Ops.get_integer(out, "exit", -1) != 0
            success = false
            log.error "Failed to commit changes in #{dir}: #{Ops.get_string(out, "stderr", "")}"
          end
        end
      end
      log.info "Commit successful: #{success}"
      success
    end

    # Create a timestamp to find changed files which are not under version control
    # @return [Boolean] true on success
    def CreateTimeStamp
      log.info "Creating timestamp to detect changes"
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("touch %1", @changes_timestamp)
        )
      )
      ret = Ops.get_integer(out, "exit", -1) == 0
      log.info "Success: #{ret}"
      ret
    end

    # Check for changed files which are not under verison control (e.g. new created files)
    # Schedule them for next commit
    # @return [Boolean] true on success, false on failure
    def CheckChangedFilesOutOfVersionControl
      success = true
      Builtins.foreach(@log_directories) do |dir|
        log.info "Checking for new files in #{dir}"
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "find %1 -newer %2 -type f |grep -v '/\\.'",
              dir,
              @changes_timestamp
            )
          )
        )
        if Ops.get_integer(out, "exit", -1) == 1
          log.info "No changes found"
          next
        end
        param = Ops.get_string(out, "stdout", "")
        files = Builtins.splitstring(param, "\n")
        files = Builtins.filter(files) { |f| f != "" }
        files = Builtins.filter(files) do |f|
          0 ==
            Convert.to_integer(
              SCR.Execute(
                path(".target.bash"),
                Builtins.sformat("svn st %1 | grep '^?'", f)
              )
            )
        end
        @commit_needed = @commit_needed ||
          Ops.greater_than(Builtins.size(files), 0)
        if Ops.greater_than(Builtins.size(files), 0)
          param = Builtins.mergestring(files, " ")
          out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat("cd %1; svn add --parents %2", dir, param)
            )
          )
          if Ops.get_integer(out, "exit", -1) != 0
            success = false
            log.error "Failed to add changes: #{Ops.get_string(out, "stderr", "")}"
          end
        end
      end
      SCR.Execute(
        path(".target.bash_output"),
        Builtins.sformat("rm %1", @changes_timestamp)
      )
      success
    end

    # Find all files which are not under version control
    # Schedule such files for next commit
    # @return [Boolean] true on success, false otherwise
    def CheckAllFilesOutOfVersionControl
      success = true
      log.info "Adding all files out of version control"
      Builtins.foreach(@log_directories) do |dir|
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "cd %1; svn add `svn st |grep '^?'|cut -d ' ' -f 7`",
              dir
            )
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          log.error "Failed to add files in #{dir}: #{Ops.get_string(out, "stderr", "")}"
          success = false
        end
      end
      @commit_needed = true # TODO check if really necessary
      log.info "Finished successfuly: #{success}"
      success
    end

    # Check for files which had been deleted, but are still in SVN
    # Schedule such files for deletion with next commit
    # @return [Boolean] true on success, false otherwise
    def RemoveDeletedFiles
      success = true
      log.info "Checking for removed files"
      Builtins.foreach(@log_directories) do |dir|
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("cd %1; svn st |grep '^!'|cut -d ' ' -f 7", dir)
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          log.error "Failed to check for deleted files in #{dir}: #{Ops.get_string(out, "stderr", "")}"
          success = false
          next
        end
        filelist = Ops.get_string(out, "stdout", "")
        files = Builtins.splitstring(filelist, " ")
        files = Builtins.filter(files) { |f| f != "" }
        next if Builtins.size(files) == 0
        filelist = Builtins.mergestring(files, " ")
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("cd %1; svn rm %2", dir, filelist)
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          log.error "Failed to remove files in #{dir}: #{Ops.get_string(out, "stderr", "")}"
          success = false
        end
      end
      @commit_needed = true # TODO check if really necessary
      log.info "Finished successfuly: #{success}"
      success
    end

    # Do commit to subversion
    # @return [Boolean] tru eon success
    def DoCommit(mod)
      log.info "Committing changes"
      arg = Builtins.mergestring(@log_directories, " ")
      log.debug "Directories to commit: #{arg}"
      log = Builtins.sformat("Changes by YaST module %1", mod)
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("cd / ; svn ci -m '%1' %2", log, arg)
        )
      )
      ret = Ops.get_integer(out, "exit", -1) == 0
      log.info "Success: #{ret}"
      ret
    end

    # Update check-out from SVN to avoid commit conflicts
    # @return [Boolean] true on success
    def UpdateCheckout
      success = true
      Builtins.foreach(@log_directories) do |dir|
        log.info "Updating configuration files in #{dir}"
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("cd %1; svn up", dir)
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          log.error "Failed to update #{dir} from SVN: #{Ops.get_string(out, "stderr", "")}"
          success = false
        end
      end
      success
    end

    # Initialize before module is started
    # Do not call CommitChanges unless Init returns true!
    # @return [Boolean] true on success, false on failure
    def Init
      return true if !UseSvn()
      if Ops.greater_than(@nested_transactions, 0)
        @nested_transactions = Ops.add(@nested_transactions, 1)
        log.info "Skiping SVN initialization, translaction already in progress"
        return true
      end
      #ensure the repo exists
      return false if !InitSvnRepository() if !CheckSvnRepository()
      return false if !InitDirectories(Recursive()) if !CheckRepoLinked()
      CheckAllFilesOutOfVersionControl() if Recursive()
      RemoveDeletedFiles()
      return false if !UpdateCheckout()
      return false if !CheckUncommitedChanges()
      return false if !CreateTimeStamp()
      @nested_transactions = Ops.add(@nested_transactions, 1)
      true
    end

    # Commit changes done by YaST into the SVN repo
    # @param [String] module_name string name of YaST module which does commit
    #        used only in the commit log
    # @return [Boolean] true on success, false on failure
    def CommitChanges(module_name)
      return true if !UseSvn()
      @nested_transactions = Ops.subtract(@nested_transactions, 1)
      if Ops.greater_than(@nested_transactions, 0)
        log.info "Skipping commit, all nested transaction not yet finished"
        return true
      end
      success = true
      if Recursive()
        success = CheckAllFilesOutOfVersionControl()
      else
        success = CheckChangedFilesOutOfVersionControl()
      end
      success = RemoveDeletedFiles() && success
      success = false if !UpdateCheckout()
      success = DoCommit(module_name) && success
      true
    end

    # Initialize specified files for version control; useful when
    # not having whole directory under version control, but only
    # relevant files
    # @param [Array<String>] files a list of files to add to repo (resp. ensure they are in)
    # @return [Boolean] true on success, false otherwise
    def InitFiles(files)
      files = deep_copy(files)
      return true if Builtins.size(files) == 0
      return true if !UseSvn()
      return true if Recursive()
      if @nested_transactions == 0
        log.error "InitFiles called before prior initialization"
        return false
      end
      filelist = Builtins.mergestring(files, " ")
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("svn add %1", filelist)
        )
      )
      if Ops.get_integer(out, "exit", -1) != 0
        log.error "Failed to schedule files #{filelist} for addition: #{Ops.get_string(out, "stderr", "")}"
        return false
      end
      success = true
      Builtins.foreach(@log_directories) do |dir|
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "cd %1; svn ci -m 'Initial check-in of files to be changed'",
              dir
            )
          )
        )
        if Ops.get_integer(out, "exit", -1) != 0
          log.error "Failed to commit changes to #{dir}: #{Ops.get_string(out, "exit", "")}"
          success = false
        end
      end
      success
    end

    publish :function => :Init, :type => "boolean ()"
    publish :function => :CommitChanges, :type => "boolean (string)"
    publish :function => :InitFiles, :type => "boolean (list <string>)"
  end

  ConfigHistory = ConfigHistoryClass.new
  ConfigHistory.main
end
