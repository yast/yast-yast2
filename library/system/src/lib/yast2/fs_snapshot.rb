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
  # Class for managing filesystem snapshots
  class FsSnapshot
    attr_reader :number, :description, :timestamp

    # Creates a new snapshot
    #
    # @param description [String] Snapshot's description.
    # @return [FsSnapshot,nil] The created snapshot if operation was successful.
    #                          Otherwise, it returns nil.
    def self.create(description)
      # TODO: Create the snapshot
      new(number, description, timestamp)
    end

    # Returns all snapshots
    #
    # @return [Array<FsSnapshot>] All snapshots that exist in the system.
    def self.all
      # Search for all snapshots
      # TODO: Retrieve snapshots
      snapshots.map do |line|
        new(number, description, timestamp)
      end
    end

    # Finds an snapshot by its number
    #
    # @param nubmer [Fixnum] Number of the snapshot to search for.
    # @return [FsSnapshot,nil] The snapshot with the number +number+ if found.
    #                          Otherwise, it returns nil.
    def self.find(number)
      all.find { |s| s.number == number }
    end

    def initialize(number, description, timestamp)
      @number = number
      @description = description
      @timestamp = timestamp
    end

    def destroy
      # TODO: destroy snapshot
    end
  end
end
