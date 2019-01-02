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
  class SystemdClient < Client
    def main
      Yast.import "Systemd"
      Yast.include self, "testsuite.rb"

      DUMP("Systemd::Running() tests")

      # Note: \0 should be used here as the separator, but YCP does not allows that...

      # test standard System V init
      TEST(->() { Systemd.Running }, [{ "target" => { "stat" => {} } }, {}, {}], nil)

      # systemd
      TEST(
        ->() { Systemd.Running },
        [{ "target" => { "stat" => { "isdir" => true } } }, {}, {}],
        nil
      )

      DUMP("Systemd::SetDefaultRunlevel() tests")

      # test invalid parameters
      TEST(->() { Systemd.SetDefaultRunlevel(nil) },
        [
          {},
          {},
          { "target" => { "bash" => 0 } }
        ], nil)

      TEST(->() { Systemd.SetDefaultRunlevel(-1) },
        [
          {},
          {},
          { "target" => { "bash" => 0 } }
        ], nil)

      TEST(->() { Systemd.SetDefaultRunlevel(7) },
        [
          {},
          {},
          { "target" => { "bash" => 0 } }
        ], nil)

      # test valid parameters
      TEST(->() { Systemd.SetDefaultRunlevel(3) },
        [
          {},
          {},
          { "target" => { "bash" => 0 } }
        ], nil)

      TEST(->() { Systemd.SetDefaultRunlevel(5) },
        [
          {},
          {},
          { "target" => { "bash" => 0 } }
        ], nil)

      # test failure
      TEST(->() { Systemd.SetDefaultRunlevel(5) },
        [
          {},
          {},
          { "target" => { "bash" => 1 } }
        ], nil)

      DUMP("Systemd::DefaultRunlevel() tests")

      # test missing / invalid (not a symlink) default
      TEST(->() { Systemd.DefaultRunlevel },
        [
          { "target" => { "symlink" => nil } },
          {},
          {}
        ], nil)

      # test numeric runlevel
      TEST(
        ->() { Systemd.DefaultRunlevel },
        [
          {
            "target" => { "symlink" => "/lib/systemd/system/runlevel3.target" }
          },
          {},
          {}
        ],
        nil
      )

      # test symbolic runlevel
      TEST(
        ->() { Systemd.DefaultRunlevel },
        [
          {
            "target" => { "symlink" => "/lib/systemd/system/graphical.target" }
          },
          {},
          {}
        ],
        nil
      )

      # test unknown symbolic runlevel
      TEST(
        ->() { Systemd.DefaultRunlevel },
        [
          {
            "target" => {
              "symlink" => "/lib/systemd/system/unknown_default.target"
            }
          },
          {},
          {}
        ],
        nil
      )

      nil
    end
  end
end

Yast::SystemdClient.new.main
