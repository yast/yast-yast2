# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2014 SUSE LLC
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
# File: hw_detection.rb
#
# Authors:
#	Ladislav Slezak <lslezak@suse.cz>
#
# Summary:
#	Module for detecting hardware
#

require "yast"

module Yast2
  class HwDetection
    include Yast::Logger

    # this is from <hd.h> include (in hwinfo-devel)
    MEMORY_CLASS = 257    # "bc_internal" value
    MEMORY_SUBCLASS = 2   # "sc_int_main_mem" value

    # Return size of the system memory (in bytes)
    # @return Fixnum,Bignum detected memory size
    def self.memory
      memory = Yast::SCR.Read(Yast::Path.new(".probe.memory"))
      log.debug("hwinfo memory: #{memory}")

      raise "Memory detection failed" unless memory

      memory_size = 0
      memory.each do |info|
        # internal class, main memory
        next if info["class_id"] != MEMORY_CLASS || info["sub_class_id"] != MEMORY_SUBCLASS

        info.fetch("resource", {}).fetch("phys_mem", []).each do |phys_mem|
          memory_size += phys_mem.fetch("range", 0)
        end
      end

      log.info("Detected memory size: #{memory_size} (#{memory_size/1024/1024}MiB)")
      memory_size
    end
  end
end
