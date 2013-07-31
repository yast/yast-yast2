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
module Yast
  class ServiceFinetuneClient < Client
    def main
      Yast.include self, "testsuite.rb"

      TESTSUITE_INIT([{ "target" => { "tmpdir" => "/tmp" } }, {}, {}], nil)

      Yast.import "Service"

      @EXEC = {
        "target" => {
          "bash"        => 0,
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      @READ = {
        "init"   => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => { "aaa" => { "start" => [], "stop" => [] } },
            "comment"  => {
              "aaa" => {
                "defstart"         => ["3", "5"],
                "defstop"          => ["0", "1", "2", "6"],
                "description"      => "description",
                "provides"         => ["aaa"],
                "reqstart"         => ["$local_fs", "$remote_fs", "$network"],
                "reqstop"          => ["$local_fs", "$remote_fs", "$network"],
                "shortdescription" => "description",
                "shouldstart"      => ["$time"],
                "shouldstop"       => ["$time"]
              }
            }
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Finetune("aaa", ["1", "3", "5"]) }, [
        @READ,
        {},
        @EXEC
      ], nil)

      @READ = {
        "init"   => { "scripts" => { "exists" => true } },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Finetune("aaa", []) }, [@READ, {}, @EXEC], nil)

      nil
    end
  end
end

Yast::ServiceFinetuneClient.new.main
