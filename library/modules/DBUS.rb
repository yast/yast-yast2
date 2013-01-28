#--
# Copyright (c) 2009-2010 Novell, Inc.
# 
# All Rights Reserved.
# 
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License
# as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
# 
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#++

#
# Generic API for calling DBus methods from YaST.
# 
# Requirements: yast2-ruby-bindings and rubygem-ruby-dbus packages need to be installed.
#
# Example usage: 
#
# DBUS::init ("org.opensuse.Snapper", "/org/opensuse/Snapper", "org.opensuse.Snapper");
#
# # When ruby code raises exception, function returns nil. Exception name can be retrieved
# # using last_exception () method. (Not DBus specific, this is ruby-bindings way)
# if (nil == DBUS::call_method ("ListConfigs", []))
# {
#       y2error ("error while calling dbus method: %1", DBUS::last_exception ());
# }
#

require "rubygems"
require "dbus"

module DBUS

  # initialize global variables
  # use to specify service/iface to work with
  def self.init(name,path,iface)
    @name       = name
    @path       = path
    @iface      = iface
  end

  # Call a DBus method of service we are working with
  # Specify method name and list of arguments (list has to be there, YaST cannot pass variable arguments number)
  def self.call_method(method, arguments)

    raise "Initialization missing" if (@name.to_s.empty? || @path.to_s.empty? || @iface.to_s.empty?)

    # connect to the system bus
    system_bus  = DBus::SystemBus.instance

    # get required service
    service     = system_bus.service(@name)
    # get the object from service
    dbus_object = service.object(@path)

    dbus_object.introspect
    dbus_object.default_iface = @iface

    reply = dbus_object.send(method,*arguments)[0]

    if reply.nil?
      return true; # with nil return value, caller should check the last exception
    else
      return reply;
    end
  rescue Exception => e
    raise e
  end

end
