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
#      initrd.ycp
#
# Module:
#      Bootloader
#
# Summary:
#      testsuite for initrd module
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#

# testedfiles: Initrd.ycp Testsuite.ycp
module Yast
  class InitrdClient < Client
    def main
      Yast.include self, "testsuite.rb"

      # minimal "don't care" SCR data to work with the constructor
      @READ = {
        "sysconfig" => { "kernel" => { "INITRD_MODULES" => "reiserfs lvmmod" } },
        "probe"     => {
          "architecture" => "i386",
          "has_pcmcia"   => false,
          "has_smp"      => false,
          "system"       => nil,
          "is_uml"       => false
        },
        "target"    => { "string" => "", "tmpdir" => "/tmp" },
        "etc"       => {
          "install_inf" => {
            "InstMode"      => "",
            "InitrdModules" => "driver1 driver2 driver3"
          }
        }
      }

      TESTSUITE_INIT([@READ, {}, {}], 0)

      Yast.import "Initrd"
      Yast.import "Mode"
      Yast.import "Stage"

      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)
      DUMP("Now reseting")
      TEST(->() { Initrd.Reset }, [@READ, {}, {}], 0)
      DUMP("Reading again")
      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)
      DUMP("Reseting again")
      TEST(->() { Initrd.Reset }, [@READ, {}, {}], 0)
      DUMP("Adding ne2k")
      TEST(->() { Initrd.AddModule("ne2k", "io=0x300, irq=5") },
        [
          @READ,
          {},
          {}
        ], 0)
      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)
      DUMP("Removing lvmmod")
      TEST(->() { Initrd.RemoveModule("lvmmod") }, [@READ, {}, {}], 0)
      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)
      DUMP("Writing")
      TEST(->() { Initrd.Write }, [@READ, {}, {}], 0)
      DUMP("Importing with filtered module")
      TEST(lambda do
        Initrd.Import(
          "list" => ["ne2k", "xfs_dmapi", "xfs_support", "lvmmod"]
        )
      end, [
        @READ,
        {},
        {}
      ], 0)
      DUMP("Writing")
      TEST(->() { Initrd.Write }, [@READ, {}, {}], 0)
      DUMP("Setting Mode::Update")
      Mode.SetMode("update")
      DUMP("Importing with filtered module")
      TEST(lambda do
        Initrd.Import(
          "list" => ["ne2k", "xfs_dmapi", "xfs_support", "lvmmod"]
        )
      end, [
        @READ,
        {},
        {}
      ], 0)
      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)
      DUMP("Writing")
      TEST(->() { Initrd.Write }, [@READ, {}, {}], 0)
      DUMP("Resetting for installation test")
      TEST(->() { Stage.Set("initial") }, [@READ, {}, {}], 0)
      TEST(->() { Mode.SetMode("installation") }, [@READ, {}, {}], 0)
      TEST(->() { Initrd.Reset }, [@READ, {}, {}], 0)
      DUMP("Testing keeping installation order")
      TEST(->() { Initrd.AddModule("ne2k", "") }, [@READ, {}, {}], 0)
      TEST(->() { Initrd.AddModule("driver3", "") }, [@READ, {}, {}], 0)
      TEST(->() { Initrd.AddModule("driver2", "") }, [@READ, {}, {}], 0)
      TEST(->() { Initrd.ListModules }, [@READ, {}, {}], 0)

      nil
    end
  end
end

Yast::InitrdClient.new.main
