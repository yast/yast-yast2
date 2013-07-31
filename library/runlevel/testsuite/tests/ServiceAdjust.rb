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
  class ServiceAdjustClient < Client
    def main
      Yast.include self, "testsuite.rb"

      TESTSUITE_INIT([{ "target" => { "tmpdir" => "/tmp" } }, {}, {}], nil)

      Yast.import "Service"

      @READ = {}
      @EXEC = {
        "target" => {
          "bash"        => 0,
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      # service does not exist
      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => {
              "aaa" => { "start" => ["0", "1", "3"], "stop" => ["4", "5", "6"] }
            },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => false
          }
        },
        "target" => { "stat" => {} }
      }
      TEST(lambda { Service.Adjust("aaa", "disable") }, [@READ, {}, @EXEC], nil)

      # service exists and may run
      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => {
              "aaa" => { "start" => ["0", "1", "3"], "stop" => ["4", "5", "6"] }
            },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "disable") }, [@READ, {}, @EXEC], nil)

      # service exists and does not run
      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => { "aaa" => { "start" => [], "stop" => [] } },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "disable") }, [@READ, {}, @EXEC], nil)

      # service exists and does not run
      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => { "aaa" => { "start" => [], "stop" => [] } },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "enable") }, [@READ, {}, @EXEC], nil)

      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => { "aaa" => { "start" => ["1"], "stop" => [] } },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "enable") }, [@READ, {}, @EXEC], nil)

      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => { "aaa" => { "start" => ["1"], "stop" => [] } },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "default") }, [@READ, {}, @EXEC], nil)

      @READ = {
        "init"   => {
          "scripts" => {
            "runlevel" => {
              "aaa" => { "start" => ["0", "1", "3"], "stop" => [] }
            },
            "comment"  => {
              "aaa" => {
                "defstart" => ["0", "1", "3"],
                "defstop"  => ["4", "5", "6"]
              }
            },
            "exists"   => true
          }
        },
        "target" => { "stat" => { "isreg" => true } }
      }
      TEST(lambda { Service.Adjust("aaa", "default") }, [@READ, {}, @EXEC], nil)

      nil
    end
  end
end

Yast::ServiceAdjustClient.new.main
