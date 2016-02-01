# ***************************************************************************
#
# Copyright (c) 2015 SUSE LLC
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

require "yast"
require "cheetah"

Yast.import "Installation"

module Yast
  # Module for executing scripts/programs in safe way. Uses cheetah as backend,
  # but adds support for chrooting in installation.
  class Execute
    # use y2log by default
    Cheetah.default_options = { logger: Y2Logger.instance }

    class << self
      include Yast::I18n
      # Runs arguments with respect of changed root in installation.
      # @see Cheetah.run for parameters
      # @raise Cheetah::ExecutionFailed
      def on_target(*args)
        root = "/"
        root = Yast::Installation.destdir if Yast::WFM.scr_chrooted?

        if args.last.is_a? ::Hash
          args.last[:chroot] = root
        else
          args.push(chroot: root)
        end

        popup_error { Cheetah.run(*args) }
      end

      # Runs arguments without changed root.
      # @see Cheetah.run for parameters
      # @raise Cheetah::ExecutionFailed
      def locally(*args)
        popup_error { Cheetah.run(*args) }
      end

    private

      def popup_error(&block)
        block.call
      rescue Cheetah::ExecutionFailed => e
        Yast.import "Report"
        textdomain "base"
        Yast::Report.Error(
          _(
            "Execution of command \"%{command}\" failed.\n"\
            "Exit code: %{exitcode}\n"\
            "Error output: %{stderr}"
          ) % {
            command:  e.commands.inspect,
            exitcode: e.status.exitstatus,
            stderr:   e.stderr
          }
        )
      end
    end
  end
end
