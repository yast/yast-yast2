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
# File:
#	Hotplug.ycp
#
# Module:
#	Hotplug
#
# Summary:
#	provide hotplug (USB, FireWire, PCMCIA) functions
#
# $Id$
#
# Authors:
#	Klaus Kaempf <kkaempf@suse.de>
#	Arvin Schnell <arvin@suse.de>
require "yast"

module Yast
  class HotplugClass < Module
    def main

      Yast.import "Arch"
      Yast.import "ModuleLoading"
      Yast.import "HwStatus"
      Yast.import "Linuxrc"

      Yast.import "Mode"

      # if a usb controller was found and initialized
      @haveUSB = false

      # if a firewire controller was found and initialized
      @haveFireWire = false
    end

    # start a controller (by loading its module)
    # return true if successfull
    # return false if failed

    def startController(controller)
      controller = deep_copy(controller)
      # check module information
      # skip controller if no module info available

      module_drivers = Ops.get_list(controller, "drivers", [])

      return true if Builtins.size(module_drivers) == 0

      # loop through all drivers checking if one is already active

      already_active = false
      Builtins.foreach(module_drivers) do |modulemap|
        already_active = true if Ops.get_boolean(modulemap, "active", true)
      end

      # save unique key for HwStatus::Set()
      unique_key = Ops.get_string(controller, "unique_key", "")

      if already_active
        HwStatus.Set(unique_key, :yes)
        return true
      end

      stop_loading = false
      one_module_failed = false

      # loop through all drivers defined for this controller
      # break after first successful load
      #   no need to check "active", already done before !

      Builtins.foreach(module_drivers) do |modulemap|
        Builtins.y2milestone("modulemap: %1", modulemap)
        module_modprobe = Ops.get_boolean(modulemap, "modprobe", false)
        all_modules_loaded = true
        if !stop_loading
          Builtins.foreach(Ops.get_list(modulemap, "modules", [])) do |module_entry|
            module_name = Ops.get_string(module_entry, 0, "")
            module_args = Ops.get_string(module_entry, 1, "")
            load_result = :ok
            if Linuxrc.manual
              vendor_device = ModuleLoading.prepareVendorDeviceInfo(controller)
              load_result = ModuleLoading.Load(
                module_name,
                module_args,
                Ops.get_string(vendor_device, 0, ""),
                Ops.get_string(vendor_device, 1, ""),
                true,
                module_modprobe
              )
            else
              load_result = ModuleLoading.Load(
                module_name,
                module_args,
                "",
                "",
                false,
                module_modprobe
              )
            end
            if load_result == :fail
              all_modules_loaded = false
            elsif load_result == :dont
              all_modules_loaded = true
            end
            # break out of module load loop if one module failed
            one_module_failed = true if !all_modules_loaded
          end # foreach module of current driver info
        end # stop_loading
        # break out of driver load loop if all modules of
        #   the current driver loaded successfully
        stop_loading = true if all_modules_loaded
      end # foreach driver

      HwStatus.Set(unique_key, one_module_failed ? :no : :yes)

      !one_module_failed
    end


    # @param	none
    #
    # @return	[void]
    # probe for usb type, load appropriate modules, and mount
    # usbfs to /proc/bus/usb

    def StartUSB
      usb_controllers = Convert.convert(
        SCR.Read(path(".probe.usbctrl")),
        :from => "any",
        :to   => "list <map>"
      )

      Builtins.foreach(usb_controllers) do |controller|
        start_result = startController(controller)
        @haveUSB = true if start_result
      end

      Builtins.y2milestone("haveUSB = %1", @haveUSB)

      nil
    end

    # @param	none
    #
    # @return	[void]
    # probe for firewire type, load appropriate modules, and mount
    # usbfs to /proc/bus/usb

    def StartFireWire
      return if Arch.sparc # why this and why here ???

      firewire_controllers = Convert.convert(
        SCR.Read(path(".probe.ieee1394ctrl")),
        :from => "any",
        :to   => "list <map>"
      )

      Builtins.foreach(firewire_controllers) do |controller|
        start_result = startController(controller)
        @haveFireWire = true if start_result
      end

      Builtins.y2milestone("haveFireWire = %1", @haveFireWire)

      nil
    end

    publish :variable => :haveUSB, :type => "boolean"
    publish :variable => :haveFireWire, :type => "boolean"
    publish :function => :StartUSB, :type => "void ()"
    publish :function => :StartFireWire, :type => "void ()"
  end

  Hotplug = HotplugClass.new
  Hotplug.main
end
