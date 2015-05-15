# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2015 SUSE LLC
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
# File: fs_snapshot.rb
#
# Authors:
#	Imobach Gonzalez Sosa <igonzalezsosa@suse.com>

require "yast"

module Yast2
  # Represents the fact that Snapper is not configured for "/" (root).
  class SnapperNotConfigured < StandardError
    def initialize
      super "Snapper is not configured."
    end
  end

  # Snapper could not be configured.
  class SnapperConfigurationFailed < StandardError
    def initialize
      super "Snapper could not be configured."
    end
  end

  # Class for managing filesystem snapshots. It's important to note that this
  # class is intended to be used during installation/update so it uses the
  # Snapper's CLI because the DBus interface is not available at that time.
  class FsSnapshot
    FIND_CONFIG_CMD = "/usr/bin/snapper --no-dbus list-configs | grep \"^root \" >/dev/null"
    CREATE_CONFIG_CMD = "/usr/bin/snapper --no-dbus create-config -f btrfs /"
    CREATE_SNAPSHOT_CMD = "/usr/lib/snapper/installation-helper --step 5 --description \"%s\""
    LIST_SNAPSHOTS_CMD = "LANG=en_US.UTF-8 /usr/bin/snapper --no-dbus list"
    VALID_LINE_REGEX = /\A\w+\s+\| \d+/

    attr_reader :number, :snapshot_type, :previous_number, :timestamp, :user,
      :cleanup_algo, :description

    # Determines whether snapper is configured or not
    #
    # @return [true,false] true if it's configured; false otherwise.
    def self.configured?
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), FIND_CONFIG_CMD)
      out["exit"] == 0
    end

    # Configures snapper
    #
    # @return [true,false] true if it's configured; false otherwise.
    def self.configure
      unless configured?
        out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), CREATE_CONFIG_CMD)
        raise SnapperConfigurationFailed unless out["exit"] == 0
      end
      true
    end

    # Creates a new snapshot
    #
    # It raises and exception if Snapper is not configured.
    #
    # @param description [String] Snapshot's description.
    # @return [FsSnapshot,nil] The created snapshot if the operation was
    #                          successful. Otherwise, it returns nil.
    def self.create(description)
      raise SnapperNotConfigured unless configured?

      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), CREATE_SNAPSHOT_CMD % description)
      if out["exit"] == 0
        find(out["stdout"].to_i) # The CREATE_SNAPSHOT_CMD returns the number of the new snapshot.
      end
    end

    # Returns all snapshots
    #
    # It raises and exception if Snapper is not configured.
    #
    # @return [Array<FsSnapshot>] All snapshots that exist in the system.
    def self.all
      raise SnapperNotConfigured unless configured?

      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), LIST_SNAPSHOTS_CMD)
      lines = out["stdout"].lines.grep(VALID_LINE_REGEX) # relevant lines from output.
      lines.map do |line|
        data = line.split("|").map(&:strip)
        timestamp = (DateTime.parse(data[3]) rescue nil)
        new(data[1].to_i, data[0].to_sym, data[2].to_i, timestamp, data[4],
          data[5].to_s.to_sym, data[6])
      end
    end

    # Finds an snapshot by its number
    #
    # It raises and exception if Snapper is not configured.
    #
    # @param nubmer [Fixnum] Number of the snapshot to search for.
    # @return [FsSnapshot,nil] The snapshot with the number +number+ if found.
    #                          Otherwise, it returns nil.
    # @see FsSnapshot.all
    def self.find(number)
      all.find { |s| s.number == number }
    end

    def initialize(number, snapshot_type, previous_number, timestamp, user, cleanup_algo, description)
      @number = number
      @snapshot_type = snapshot_type
      @previous_number = previous_number
      @timestamp = timestamp
      @user = user
      @cleanup_algo = cleanup_algo
      @description = description
    end

    def previous
      @previous ||= FsSnapshot.find(@previous_number)
    end
  end
end
