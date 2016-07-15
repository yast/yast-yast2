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

# testedfiles: Kernel.ycp Testsuite.ycp
module Yast
  class KernelClient < Client
    def main
      Yast.include self, "testsuite.rb"

      # minimal "don't care" SCR data to work with the constructor
      @READ =
        # 	"etc" : $[
        # 	    "install_inf" : $[
        # 		"InstMode" : "",
        # 	    ],
        # 	],
        {
          "sysconfig" => {
            "kernel" => { "MODULES_LOADED_ON_BOOT" => "reiserfs xfs" }
          },
          "probe"     => {
            "architecture" => "i386",
            "has_pcmcia"   => false,
            "has_smp"      => false,
            "system"       => nil,
            "is_uml"       => false,
            "memory"       => []
          },
          "proc"      => {
            "cpuinfo" => { "value" => { "0" => { "flags" => "" } } }
          },
          "target"    => { "tmpdir" => "/tmp" }
        }
      @WRITE = {}
      @EXEC = {}

      TESTSUITE_INIT([@READ, {}, {}], 0)

      Yast.import "Kernel"
      Yast.import "Mode"

      Mode.SetTest("testsuite")

      # test behavior of modules loaded on boot
      DUMP("----------------------------------------")

      TEST(->() { Kernel.HidePasswords(nil) }, [@READ, @WRITE, @EXEC], 0)
      TEST(->() { Kernel.HidePasswords("") }, [@READ, @WRITE, @EXEC], 0)
      TEST(->() { Kernel.HidePasswords("ABC=213 DEF=324") },
        [
          @READ,
          @WRITE,
          @EXEC
        ], 0)
      TEST(->() { Kernel.HidePasswords(" ABC=213  DEF=324 ") },
        [
          @READ,
          @WRITE,
          @EXEC
        ], 0)
      TEST(->() { Kernel.HidePasswords("ABC=213 DEF=324 FTPPASSWORD=pass") },
        [
          @READ,
          @WRITE,
          @EXEC
        ], 0)

      nil
    end
  end
end

Yast::KernelClient.new.main
