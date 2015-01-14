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
# File:	include/hwinfo/classnames.ycp
# Module:	Hardware information
# Summary:	Class DB file
# Authors:	Dan Meszaros <dmeszar@suse.cz>
#		Ladislav Slezak <lslezak@suse.cz>
#		Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Since hardware description string disappeared from libhd in june-2001
# this translation table must be used to obtain those descriptions.
#
# see file src/ids/src/class in hwinfo sources
module Yast
  module HwinfoClassnamesInclude
    def initialize_hwinfo_classnames(_include_target)
      textdomain "base"

      # Class names collected
      @ClassNames = {
        0   => {
          "name" => _("Unclassified device"),
          0      => _("Unclassified device"),
          1      => _("VGA compatible unclassified device")
        },
        1   => {
          "name" => _("Mass storage controller"),
          0      => _("SCSI storage controller"),
          1      => _("IDE interface"),
          2      => _("Floppy disk controller"),
          3      => _("IPI bus controller"),
          4      => _("RAID bus controller"),
          128    => _("Unknown mass storage controller")
        },
        2   => {
          "name" => _("Network controller"),
          0      => _("Ethernet controller"),
          1      => _("Token ring network controller"),
          2      => _("FDDI network controller"),
          3      => _("ATM network controller"),
          4      => _("ISDN controller"),
          128    => _("Network controller"),
          129    => _("Myrinet controller")
        },
        3   => {
          "name" => _("Display controller"),
          0      => _("VGA-compatible controller"),
          1      => _("XGA-compatible controller"),
          2      => _("3D controller"),
          128    => _("Display controller")
        },
        4   => {
          "name" => _("Multimedia controller"),
          0      => _("Multimedia video controller"),
          1      => _("Multimedia audio controller"),
          2      => _("Computer telephony device"),
          128    => _("Multimedia controller")
        },
        5   => {
          "name" => _("Memory controller"),
          0      => _("RAM memory"),
          1      => _("FLASH memory"),
          128    => _("Memory controller")
        },
        6   => {
          "name" => _("Bridge"),
          0      => _("Host bridge"),
          1      => _("ISA bridge"),
          2      => _("EISA bridge"),
          3      => _("MicroChannel bridge"),
          4      => _("PCI bridge"),
          5      => _("PCMCIA bridge"),
          6      => _("NuBus bridge"),
          7      => _("CardBus bridge"),
          8      => _("RACEway bridge"),
          9      => _("Semitransparent PCI-to-PCI bridge"),
          10     => _("InfiniBand to PCI host bridge"),
          128    => _("Bridge")
        },
        7   => {
          "name" => _("Communication controller"),
          0      => _("Serial controller"),
          1      => _("Parallel controller"),
          2      => _("Multiport serial controller"),
          3      => _("Modem"),
          128    => _("Communication controller")
        },
        8   => {
          "name" => _("Generic system peripheral"),
          0      => _("PIC"),
          1      => _("DMA controller"),
          2      => _("Timer"),
          3      => _("RTC"),
          4      => _("PCI hotplug controller"),
          128    => _("System peripheral")
        },
        9   => {
          "name" => _("Input device controller"),
          0      => _("Keyboard controller"),
          1      => _("Digitizer pen"),
          2      => _("Mouse controller"),
          3      => _("Scanner controller"),
          4      => _("Gameport controller"),
          128    => _("Input device controller")
        },
        10  => {
          "name" => _("Docking station"),
          0      => _("Generic docking station"),
          128    => _("Docking station")
        },
        11  => {
          "name" => _("Processor"),
          0      => _("386"),
          1      => _("486"),
          2      => _("Pentium"),
          16     => _("Alpha"),
          32     => _("Power PC"),
          48     => _("MIPS"),
          64     => _("Coprocessor")
        },
        12  => {
          "name" => _("Serial bus controller"),
          0      => _("FireWire (IEEE 1394)"),
          1      => _("ACCESS bus"),
          2      => _("SSA"),
          3      => _("USB controller"),
          4      => _("Fiber channel"),
          5      => _("SMBus"),
          6      => _("InfiniBand")
        },
        13  => {
          "name" => _("Wireless controller"),
          0      => _("IRDA controller"),
          1      => _("Consumer IR controller"),
          16     => _("RF controller"),
          128    => _("Wireless controller")
        },
        14  => { "name" => _("Intelligent controller"), 0 => _("I2O") },
        15  => {
          "name" => _("Satellite communications controller"),
          0      => _("Satellite TV controller"),
          1      => _("Satellite audio communication controller"),
          3      => _("Satellite voice communication controller"),
          4      => _("Satellite data communication controller")
        },
        16  => {
          "name" => _("Encryption controller"),
          0      => _("Network and computing encryption device"),
          16     => _("Entertainment encryption device"),
          128    => _("Encryption controller")
        },
        17  => {
          "name" => _("Signal processing controller"),
          0      => _("DPIO module"),
          1      => _("Performance counters"),
          16     => _("Communication synchronizer"),
          128    => _("Signal processing controller")
        },
        255 => { "name" => _("Unclassified device") },
        256 => {
          "name" => _("Monitor"),
          1      => _("CRT monitor"),
          2      => _("LCD monitor")
        },
        257 => {
          "name" => _("Internally used class"),
          1      => _("ISA PnP interface"),
          2      => _("Main memory"),
          3      => _("CPU"),
          4      => _("FPU"),
          5      => _("BIOS"),
          6      => _("PROM"),
          7      => _("System")
        },
        258 => { "name" => _("Modem"), 0 => _("Modem"), 1 => _("Win modem") },
        259 => { "name" => _("ISDN adapter") },
        260 => { "name" => _("PS/2 controller") },
        261 => {
          "name" => _("Mouse"),
          0      => _("PS/2 mouse"),
          1      => _("Serial mouse"),
          2      => _("Bus mouse"),
          3      => _("USB mouse"),
          128    => _("Mouse")
        },
        262 => {
          "name" => _("Mass storage device"),
          0      => _("Disk"),
          1      => _("Tape"),
          2      => _("CD-ROM"),
          3      => _("Floppy disk"),
          128    => _("Storage device")
        },
        263 => {
          "name" => _("Network interface"),
          0      => _("Loopback"),
          1      => _("Ethernet"),
          2      => _("Token ring"),
          3      => _("FDDI"),
          4      => _("CTC"),
          5      => _("IUCV"),
          6      => _("HSI"),
          7      => _("QETH"),
          8      => _("ESCON"),
          9      => _("Myrinet"),
          128    => _("Network interface")
        },
        264 => {
          "name" => _("Keyboard"),
          0      => _("Keyboard"),
          1      => _("Console")
        },
        265 => { "name" => _("Printer") },
        266 => { "name" => _("Hub"), 1 => _("USB hub") },
        267 => { "name" => _("Braille display") },
        268 => { "name" => _("Scanner") },
        269 => { "name" => _("Joystick"), 1 => _("Gamepad") },
        270 => { "name" => _("Chipcard reader") },
        271 => {
          "name" => _("Camera"),
          1      => _("Webcam"),
          2      => _("Digital camera")
        },
        272 => { "name" => _("Framebuffer"), 1 => _("VESA framebuffer") },
        273 => {
          "name" => _("DVB card"),
          1      => _("DVB-C card"),
          2      => _("DVB-S card"),
          3      => _("DVB-T card")
        },
        274 => { "name" => _("TV card") },
        275 => { "name" => _("Partition") },
        276 => { "name" => _("DSL card") },
        277 => { "name" => _("Bluetooth device") }
      } 

      # EOF
    end
  end
end
