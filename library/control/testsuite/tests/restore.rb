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
  class RestoreClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "ProductFeatures"

      @READ = {
        "product" => {
          "features" => {
            "USE_DESKTOP_SCHEDULER"           => "0",
            "ENABLE_AUTOLOGIN"                => "yes",
            "EVMS_CONFIG"                     => "0",
            "IO_SCHEDULER"                    => "cfg",
            "UI_MODE"                         => "expert",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "95"
          }
        }
      }

      TEST(->() { ProductFeatures.GetStringFeature("globals", "ui_mode") },
        [
          @READ
        ], 0)
      TEST(lambda do
        ProductFeatures.GetStringFeature("globals", "enable_autologin")
      end, [
        @READ
      ], 0)
      TEST(lambda do
        ProductFeatures.GetBooleanFeature("globals", "enable_autologin")
      end, [
        @READ
      ], 0)
      TEST(lambda do
        ProductFeatures.GetIntegerFeature(
          "globals",
          "incomplete_translation_treshold"
        )
      end, [
        @READ
      ], 95)

      nil
    end
  end
end

Yast::RestoreClient.new.main
