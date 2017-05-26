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

module Yast
  # Module for executing scripts/programs in safe way. Uses cheetah as backend,
  # but adds support for chrooting in installation.
  class Execute
    # use y2log by default
    Cheetah.default_options = { logger: Y2Logger.instance }

    extend Yast::I18n
    textdomain "base"

    # Runs arguments with respect of changed root in installation. Shows popup when failed and returns nil in such case.
    # @see http://www.rubydoc.info/github/openSUSE/cheetah/Cheetah.run parameter docs
    def self.on_target(*args)
      popup_error { on_target!(*args) }
    end

    # Runs arguments with respect of changed root in installation.
    # @see http://www.rubydoc.info/github/openSUSE/cheetah/Cheetah.run parameter docs
    # @raise Cheetah::ExecutionFailed when command failed, see cheetah documentation
    def self.on_target!(*args)
      root = Yast::WFM.scr_root

      if args.last.is_a? ::Hash
        args.last[:chroot] = root
      else
        args.push(chroot: root)
      end

      Cheetah.run(*args)
    end

    # Runs arguments without changed root. Shows popup when failed and returns nil in such case.
    # @see http://www.rubydoc.info/github/openSUSE/cheetah/Cheetah.run parameter docs
    def self.locally(*args)
      popup_error { locally!(*args) }
    end

    # Runs arguments without changed root.
    # @see http://www.rubydoc.info/github/openSUSE/cheetah/Cheetah.run parameter docs
    # @raise Cheetah::ExecutionFailed when command failed, see cheetah documentation
    def self.locally!(*args)
      Cheetah.run(*args)
    end

    private_class_method def self.popup_error(&block)
      block.call
    rescue Cheetah::ExecutionFailed => e
      Yast.import "Report"

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
