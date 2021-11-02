# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

module Y2Packager
  # Implements support for a software management system
  #
  # To implement support for an additional backend, just inherit from this class
  # and implement the corresponding methods (e.g., #probe, #repositories, #search, etc.).
  class Backend
    # Initializes the backend
    def probe; end

    # Returns the list of repositories
    #
    # @return [Array<Repository>]
    def repositories
      []
    end

    # Returns the resolvables according to the given conditions and properties
    #
    # @todo Return a ResolvablesCollection instance.
    #
    # @param conditions [Hash<Symbol,String>] Search conditions (e.g., { name: "SLES" }
    # @param properties [Array<Symbol>] List of properties to include in the result.
    #   The default list is defined by each backend.
    # @return [Array<Resolvable>]
    def search(*)
      []
    end
  end
end
