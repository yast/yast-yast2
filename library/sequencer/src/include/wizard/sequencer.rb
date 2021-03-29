# typed: false
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
# File:  include/wizard/sequencer.ycp
# Module:  yast2
# Summary:  Wizard sequencer
# Authors:  Michal Svec <msvec@suse.cz>
#
# $Id$
#
# This include is obsolete and for compatibility only.
# Use module Sequencer instead.
module Yast
  module WizardSequencerInclude
    def initialize_wizard_sequencer(_include_target)
      Yast.import "Sequencer"
    end

    def WizardSequencer(aliases, sequence)
      aliases = deep_copy(aliases)
      sequence = deep_copy(sequence)
      Builtins.y2warning("The sequencer include is obsolete")
      Builtins.y2warning("Use Sequencer module instead")
      Sequencer.Run(aliases, sequence)
    end
  end
end
