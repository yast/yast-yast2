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
require "date"

module Yast2
  # Represents the fact that Snapper is not configured for "/" (root).
  class SnapperNotConfigured < StandardError
    def initialize
      super "Programming error: Snapper is not configured yet."
    end
  end

  # Represents that does not exist a suitable 'pre' snapshot for a new 'post'
  # snapshot.
  class PreviousSnapshotNotFound < StandardError
    def initialize
      super "Previous snapshot was not found."
    end
  end

  # Represents the fact that the snapshot could not be created.
  class SnapshotCreationFailed < StandardError
    def initialize
      super "Filesystem snapshot could not be created."
    end
  end

  # Class for managing filesystem snapshots. It's important to note that this
  # class is intended to be used during installation/update so it uses the
  # Snapper's CLI because the DBus interface is not available at that time.
  class FsSnapshot
    include Yast::Logger

    Yast.import "Linuxrc"

    FIND_CONFIG_CMD = "/usr/bin/snapper --no-dbus --root=%{root} list-configs | grep \"^root \" >/dev/null".freeze
    CREATE_SNAPSHOT_CMD = "/usr/lib/snapper/installation-helper --step 5 --root-prefix=%{root} --snapshot-type %{snapshot_type} --description \"%{description}\"".freeze
    LIST_SNAPSHOTS_CMD = "LANG=en_US.UTF-8 /usr/bin/snapper --no-dbus --root=%{root} list".freeze
    VALID_LINE_REGEX = /\A\w+\s+\| \d+/

    # Predefined snapshot cleanup strategies (the user can define custom ones, too)
    CLEANUP_STRATEGY = { number: "number", timeline: "timeline" }.freeze

    attr_reader :number, :snapshot_type, :previous_number, :timestamp, :user,
      :cleanup_algo, :description

    # Determines whether snapper is configured or not
    #
    # @return [true,false] true if it's configured; false otherwise.
    def self.configured?
      return @configured unless @configured.nil?

      out = Yast::SCR.Execute(
        Yast::Path.new(".target.bash_output"),
        format(FIND_CONFIG_CMD, root: target_root)
      )

      log.info("Checking if Snapper is configured: \"#{FIND_CONFIG_CMD}\" returned: #{out}")
      @configured = out["exit"] == 0
    end

    # Returns whether creating the given snapshot type is allowed
    # Information is taken from Linuxrc (DISABLE_SNAPSHOTS)
    #   * "all" - all snapshot types are temporarily disabled
    #   * "around" - before and after calling YaST
    #   * "single" - single snapshot at a given point
    #
    # @param [Symbol] one of :around (for :post and :pre snapshots) or :single
    # @return [Boolean] if snapshot should be created
    def self.create_snapshot?(snapshot_type)
      disable_snapshots = Yast::Linuxrc.value_for(Yast::LinuxrcClass::DISABLE_SNAPSHOTS)

      # Feature is not defined on Linuxrc commandline
      return true if disable_snapshots.nil? || disable_snapshots.empty?

      disable_snapshots = disable_snapshots.downcase.tr("-_.", "").split(",")

      if [:around, :single].include?(snapshot_type)
        return false if disable_snapshots.include?("all")
        return !disable_snapshots.include?(snapshot_type.to_s)
      else
        raise ArgumentError, "Unsupported snapshot type #{snapshot_type.inspect}, " \
              "supported are :around and :single"
      end
    end

    # Creates a new 'single' snapshot unless disabled by user
    #
    # @param description [String]  Snapshot's description.
    # @param cleanup     [String]  Cleanup strategy (:number, :timeline, nil)
    # @param important   [boolean] Add "important" to userdata?
    # @return [FsSnapshot] The created snapshot.
    #
    # @see FsSnapshot.create
    # @see FsSnapshot.create_snapshot?
    def self.create_single(description, cleanup: nil, important: false)
      return nil unless create_snapshot?(:single)

      create(:single, description, cleanup: cleanup, important: important)
    end

    # Creates a new 'pre' snapshot
    #
    # @param description [String] Snapshot's description.
    # @return [FsSnapshot] The created snapshot.
    #
    # @see FsSnapshot.create
    # @see FsSnapshot.create_snapshot?
    def self.create_pre(description, cleanup: nil, important: false)
      return nil unless create_snapshot?(:around)

      create(:pre, description, cleanup: cleanup, important: important)
    end

    # Creates a new 'post' snapshot unless disabled by user
    #
    # Each 'post' snapshot corresponds with a 'pre' one.
    #
    # @param description     [String]  Snapshot's description.
    # @param previous_number [Fixnum]  Number of the previous snapshot
    # @param cleanup         [String]  Cleanup strategy (:number, :timeline, nil)
    # @param important       [boolean] Add "important" to userdata?
    # @return [FsSnapshot] The created snapshot.
    #
    # @see FsSnapshot.create
    # @see FsSnapshot.create_snapshot?
    def self.create_post(description, previous_number, cleanup: nil, important: false)
      return nil unless create_snapshot?(:around)

      previous = find(previous_number)

      if previous
        create(:post, description, previous: previous, cleanup: cleanup, important: important)
      else
        log.error "Previous filesystem snapshot was not found"
        raise PreviousSnapshotNotFound
      end
    end

    # Creates a new snapshot unless disabled by user
    #
    # It raises an exception if Snapper is not configured or if snapshot
    # creation fails.
    #
    # @param snapshot_type [Symbol]    Snapshot's type: :pre, :post or :single.
    # @param description   [String]    Snapshot's description.
    # @param previous      [FsSnashot] Previous snapshot.
    # @param cleanup       [String]    Cleanup strategy (:number, :timeline, nil)
    # @param important     [boolean]   Add "important" to userdata?
    # @return [FsSnapshot] The created snapshot if the operation was
    #                      successful.
    def self.create(snapshot_type, description, previous: nil, cleanup: nil, important: false)
      raise SnapperNotConfigured unless configured?

      cmd = format(CREATE_SNAPSHOT_CMD,
        root:          target_root,
        snapshot_type: snapshot_type,
        description:   description)
      cmd << " --pre-num #{previous.number}" if previous
      cmd << " --userdata \"important=yes\"" if important

      if cleanup
        strategy = CLEANUP_STRATEGY[cleanup]
        cmd << " --cleanup \"#{strategy}\"" if strategy
      end

      log.info("Executing: \"#{cmd}\"")
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)

      if out["exit"] == 0
        find(out["stdout"].to_i) # The CREATE_SNAPSHOT_CMD returns the number of the new snapshot.
      else
        log.error "Snapshot could not be created: #{cmd} returned: #{out}"
        raise SnapshotCreationFailed
      end
    end
    private_class_method :create

    # detects if module runs in initial stage before scr is switched to target system
    def self.non_switched_installation?
      Yast.import "Stage"
      return false unless Yast::Stage.initial

      !Yast::WFM.scr_chrooted?
    end
    private_class_method :non_switched_installation?

    # Gets target directory on which should snapper operate
    def self.target_root
      return "/" unless non_switched_installation?

      Yast.import "Installation"

      Yast::Installation.destdir
    end
    private_class_method :target_root

    # Returns all snapshots
    #
    # It raises an exception if Snapper is not configured.
    #
    # @return [Array<FsSnapshot>] All snapshots that exist in the system.
    def self.all
      raise SnapperNotConfigured unless configured?

      out = Yast::SCR.Execute(
        Yast::Path.new(".target.bash_output"),
        format(LIST_SNAPSHOTS_CMD, root: target_root)
      )
      lines = out["stdout"].lines.grep(VALID_LINE_REGEX) # relevant lines from output.
      log.info("Retrieving snapshots list: #{LIST_SNAPSHOTS_CMD} returned: #{out}")
      lines.each_with_object([]) do |line, snapshots|
        data = line.split("|").map(&:strip)
        next if data[1] == "0" # Ignores 'current' snapshot (id = 0) because it's not a real snapshot
        begin
          timestamp = DateTime.parse(data[3])
        rescue ArgumentError
          log.warn("Error when parsing date/time: #{timestamp}")
          timestamp = nil
        end
        previous_number = data[2] == "" ? nil : data[2].to_i
        snapshots << new(data[1].to_i, data[0].to_sym, previous_number, timestamp,
          data[4], data[5].to_sym, data[6])
      end
    end

    # Finds a snapshot by its number
    #
    # It raises an exception if Snapper is not configured.
    #
    # @param nubmer [Fixnum] Number of the snapshot to search for.
    # @return [FsSnapshot,nil] The snapshot with the number +number+ if found.
    #                          Otherwise, it returns nil.
    # @see FsSnapshot.all
    def self.find(number)
      all.find { |s| s.number == number }
    end

    # FsSnapshot constructor
    #
    # This method is not intended to be called by users of FsSnapshot class.
    # Instead, class methods must be used.
    #
    # @param number          [Fixnum]        Snapshot's number.
    # @param snapshot_type   [Symbol]        Snapshot's type: :pre, :post or :single.
    # @param previous_number [Fixnum]        Previous snapshot's number.
    # @param timestamp       [DateTime]      Timestamp
    # @param user            [String]        Snapshot's owner username.
    # @param cleanup_algo    [String]        Clean-up algorithm.
    # @param description     [String]        Snapshot's description.
    # @return [FsSnapshot] New FsSnapshot object.
    def initialize(number, snapshot_type, previous_number, timestamp, user, cleanup_algo, description)
      @number = number
      @snapshot_type = snapshot_type
      @previous_number = previous_number
      @timestamp = timestamp
      @user = user
      @cleanup_algo = cleanup_algo
      @description = description
    end

    private_class_method :new

    # Returns the previous snapshot
    #
    # @return [FsSnapshot, nil] Object representing the previous snapshot.
    def previous
      @previous ||= @previous_number ? FsSnapshot.find(@previous_number) : nil
    end
  end
end
