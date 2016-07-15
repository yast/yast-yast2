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
#      filechanges.ycp
#
# Module:
#      Base
#
# Summary:
#      testsuite for filechanges module
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id: kernel.ycp 26253 2005-11-22 14:59:29Z lslezak $
#

# testedfiles: Kernel.ycp Testsuite.ycp
module Yast
  class FilechangesClient < Client
    def main
      Yast.include self, "testsuite.rb"

      # minimal "don't care" SCR data to work with the constructor
      @READ = {
        "target" => {
          "string" => "",
          "tmpdir" => "/tmp",
          "size"   => 5,
          "ycp"    => {}
        }
      }
      @WRITE = {}
      @EXECL = [
        {
          "target" => {
            "bash_output" => {
              "exit"   => 0,
              "stdout" => "ntp.rpm",
              "stderr" => ""
            }
          }
        },
        {
          "target" => {
            "bash_output" => {
              "exit"   => 0,
              "stdout" => "S.?....T    /etc/ntp.conf\n..?.....  c /var/lib/ntp/etc/ntp.conf.iburst",
              "stderr" => ""
            }
          }
        }
      ]

      TESTSUITE_INIT([@READ, {}, {}], 0)

      Yast.import "FileChanges"
      Yast.import "Mode"

      Mode.SetTest("testsuite")
      TEST(->() { FileChanges.FileChanged("/etc/ntp.conf") },
        [
          @READ,
          @WRITE,
          @EXECL
        ], nil)
      Ops.set(@READ, ["target", "ycp", "/etc/ntp.conf"], "incorrect checksum")
      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => "0",
            "stdout" => "f210720e1362615ac0ecc544b35abb73  /etc/ntp.conf"
          }
        }
      }

      TEST(->() { FileChanges.FileChanged("/etc/ntp.conf") },
        [
          @READ,
          @WRITE,
          @EXEC
        ], nil)
      Ops.set(
        @READ,
        ["target", "ycp", "/etc/ntp.conf"],
        "f210720e1362615ac0ecc544b35abb73  /etc/ntp.conf"
      )
      TEST(->() { FileChanges.FileChanged("/etc/ntp.conf") },
        [
          @READ,
          @WRITE,
          @EXEC
        ], nil)

      TEST(->() { FileChanges.CheckNewCreatedFiles([]) },
        [
          @READ,
          @WRITE,
          @EXEC
        ], true)

      Ops.set(
        @READ,
        ["target", "stat", "/var/lib/YaST2/filechecks_non_verbose"],
        {}
      )
      TEST(->() { FileChanges.CheckNewCreatedFiles(["/etc/apache2/vhosts.d/vhost1"]) },
        [
          @READ,
          @WRITE,
          @EXEC
        ], true)

      nil
    end
  end
end

Yast::FilechangesClient.new.main
