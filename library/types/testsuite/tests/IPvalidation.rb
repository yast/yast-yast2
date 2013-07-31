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
# File:	IPvalidation.ycp
# Package:	yast2
# Summary:	ipaddress type validation test
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
module Yast
  class IPvalidationClient < Client
    def main
      Yast.include self, "testsuite.rb"
      @READ = { "target" => { "tmpdir" => "/tmp" } }
      TESTSUITE_INIT([@READ], nil)

      Yast.import "TypeRepository"

      # correct IPv4
      TEST(lambda { TypeRepository.is_a("10.20.0.0", "ip") }, [], nil)
      # incorrect IPv4
      TEST(lambda { TypeRepository.is_a("10.blem.0.0", "ip") }, [], nil)
      # correct IPv6
      TEST(lambda { TypeRepository.is_a("fe80::250:fcff:fe74:f702", "ip") }, [], nil) 

      # EOF

      nil
    end
  end
end

Yast::IPvalidationClient.new.main
