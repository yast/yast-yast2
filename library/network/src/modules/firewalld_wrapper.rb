# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

require "yast"
require "y2firewall/firewalld"

module Yast
  # This module add support for handling firewalld configuration and it is
  # mainly a firewalld wrapper. It is inteded to be used mostly by YaST
  # modules written in Perl like yast-dns-server.
  class FirewalldWrapperClass < Module
    def read
      firewalld.read
    end

    def write
      firewalld.write
    end

    def write_only
      firewalld.write_only
    end

    publish function: :read, type: "boolean (string)"
    publish function: :write, type: "boolean (string)"
    publish function: :write_only, type: "boolean (string)"

  private

    def firewalld
      Y2Firewall::Firewalld.instance
    end
  end

  FirewalldWrapper = FirewalldWrapperClass.new
end
