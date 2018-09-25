# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2016 Novell, Inc.
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
#
# File:        modules/SuSEFirewall.rb
# Authors:     Markos Chandras <mchandras@suse.de>, Karol Mroz <kmroz@suse.de>
#
# $Id$
#
# Module for handling SuSEfirewall2 or FirewallD
require "yast"
require "network/firewall_chooser"
require "network/susefirewall2"

module Yast
  SuSEFirewall = FirewallChooser.new.choose
  SuSEFirewall.main if SuSEFirewall.is_a?(SuSEFirewall2Class)
end
