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
# File:	modules/Mode.ycp
# Module:	yast2
# Summary:	Installation mode
# Authors:	Klaus Kaempf <kkaempf@suse.de>
# Flags:	Stable
#
# $Id$
#
# Provide installation mode information.
# Mostly values from /etc/install.inf
# See linuxrc documentation for detailed docs about this.
require "yast"

module Yast
  # There are three modes combined here:
  #
  # 1. Installation
  # 2. UI
  # 3. Test
  #
  # See also {StageClass Stage}
  #
  # # *Installation* mode
  #
  # It is the most complex one. Its values are used in the installation
  # {https://github.com/yast/?query=skelcd-control control files}.
  #
  # It has these mutually exclusive values and corresponding boolean queries:
  # <table>
  # <tr><th> {#mode} value </th>    <th colspan=2> boolean shortcut   </th></tr>
  # <tr><td> normal </td>           <td colspan=2> {#normal}          </td></tr>
  # <tr><td> installation </td>     <td rowspan=3> {#installation}    </td></tr>
  # <tr><td> autoinstallation </td> <td>         {#autoinst} (short!) </td></tr>
  # <tr><td> live_installation </td><td>         {#live_installation} </td></tr>
  # <tr><td> autoinst_config </td>  <td colspan=2> {#config}          </td></tr>
  # <tr><td> update </td>           <td rowspan=2> {#update}          </td></tr>
  # <tr><td> autoupgrade </td>      <td>           {#autoupgrade}     </td></tr>
  # <tr><td> repair (obsolete) </td><td colspan=2> {#repair}          </td></tr>
  # </table>
  #
  # Set with {#SetMode}.
  #
  # # *UI* mode
  #
  # It has these mutually exclusive values and corresponding boolean queries:
  # <table>
  # <tr><th> {#ui} value</th>   <th> boolean shortcut </th></tr>
  # <tr><td> dialog       </td> <td> (none)           </td></tr>
  # <tr><td> commandline  </td> <td> {#commandline}   </td></tr>
  # <tr><td> none(*)      </td> <td> (none)           </td></tr>
  # </table>
  #
  # Apparently "none" is never used.
  #
  # Set with {#SetUI}.
  #
  # # *Test* mode
  #
  # It has these mutually exclusive values and corresponding boolean queries:
  # <table>
  # <tr><th> {#testMode} value</th>  <th colspan=2> boolean shortcut </th> </tr>
  # <tr><td> test </td>              <td rowspan=3> {#test} </td></tr>
  # <tr><td> testsuite  </td>        <td> {#testsuite}      </td></tr>
  # <tr><td> screenshot </td>        <td> {#screen_shot} (underscore!)</td></tr>
  # </table>
  #
  # Set with {#SetTest}.
  class ModeClass < Module
    def main

      textdomain "base"

      # Current mode
      @_mode = nil

      # Current testing mode
      @_test = nil

      # We do one automatic check whether _test should be set to testsuite.
      @test_autochecked = false

      # Current UI mode
      @_ui = "dialog"
    end

    # initialize everything from command-line of y2base
    def Initialize
      @_mode = "normal"
      @_test = "none"
      arg_count = Builtins.size(WFM.Args)
      arg_no = 0
      while Ops.less_than(arg_no, arg_count)
        # parsing for main mode
        if WFM.Args(arg_no) == "initial" || WFM.Args(arg_no) == "continue" ||
            WFM.Args(arg_no) == "firstboot"
          @_mode = "installation"
        # parsing for test mode
        elsif WFM.Args(arg_no) == "test" || WFM.Args(arg_no) == "demo"
          @_test = "test"
          Builtins.y2warning("***** Test mode enabled *****")
        elsif WFM.Args(arg_no) == "screenshots"
          @_test = "screenshot"
          Builtins.y2warning("***** Screen shot mode enabled *****")
        end

        arg_no = Ops.add(arg_no, 1)
      end

      # only use the /etc/install.inf agent when file is present
      # and installation is being processed
      # FIXME remove the part below and let it be set in clients
      if @_mode == "installation" &&
          SCR.Read(path(".target.size"), "/etc/install.inf") != -1

        autoinst = SCR.Read(path(".etc.install_inf.AutoYaST")) != nil
        @_mode = "autoinstallation" if autoinst

        repair = SCR.Read(path(".etc.install_inf.Repair")) != nil
        @_mode = "repair" if repair

        # FIXME according to what Linuxrc really writes
        autoupgrade = SCR.Read(path(".etc.install_inf.AutoUpgrade")) != nil
        @_mode = "autoupgrade" if autoupgrade

        update = SCR.Read(path(".etc.install_inf.Upgrade")) != nil
        @_mode = "update" if update
      end

      nil
    end

    # main mode definitions

    # Returns the current mode name. It's one of
    # "installation", "normal", "update", "repair", "autoinstallation", "autoinst_config"
    def mode
      Initialize() if @_mode == nil

      @_mode
    end

    def SetMode(new_mode)
      Initialize() if @_mode == nil

      if !Builtins.contains(
          [
            "installation",
            "update",
            "normal",
            "repair",
            "autoinstallation",
            "autoinst_config",
            "live_installation",
            "autoupgrade"
          ],
          new_mode
        )
        Builtins.y2error("Unknown mode %1", new_mode)
      end

      Builtins.y2milestone("setting mode to %1", new_mode)
      @_mode = new_mode

      nil
    end

    # test mode definitions

    def testMode
      Initialize() if @_test == nil
      if !@test_autochecked
        # bnc#243624#c13: Y2ALLGLOBAL is set by yast2-testsuite/skel/runtest.sh
        if Builtins.getenv("Y2MODETEST") != nil ||
            Builtins.getenv("Y2ALLGLOBAL") != nil
          @_test = "testsuite"
        end
        @test_autochecked = true
      end

      @_test
    end

    def SetTest(new_test_mode)
      Initialize() if @_test == nil

      if !Builtins.contains(
          ["none", "test", "demo", "screenshot", "testsuite"],
          new_test_mode
        )
        Builtins.y2error("Unknown test mode %1", new_test_mode)
      end
      @_test = new_test_mode

      nil
    end

    # UI mode definitions

    # Returns the current UI mode.
    # It's one of "commandline", "dialog", "none"
    def ui
      @_ui
    end

    def SetUI(new_ui)
      if !Builtins.contains(["commandline", "dialog", "none"], new_ui)
        Builtins.y2error("Unknown UI mode %1", new_ui)
      end
      @_ui = new_ui

      nil
    end

    # main mode wrappers

    # we're doing a fresh installation
    def installation
      mode == "installation" || mode == "autoinstallation" ||
        mode == "live_installation"
    end

    # we're doing a fresh installation from live CD/DVD
    def live_installation
      mode == "live_installation"
    end

    # we're doing an update
    def update
      mode == "update" || mode == "autoupgrade"
    end

    def Depeche
      true
    end

    # normal, running system
    def normal
      mode == "normal"
    end

    # start repair module
    def repair
      mode == "repair"
    end

    # doing auto-installation
    def autoinst
      mode == "autoinstallation"
    end

    # doing auto-upgrade
    def autoupgrade
      mode == "autoupgrade"
    end

    # configuration for auto-installation, only in running system
    def config
      mode == "autoinst_config"
    end

    # test mode wrappers

    # Just testing.
    # See installation/Test-Scripts/doit*
    def test
      testMode == "test" || testMode == "screenshot" || testMode == "testsuite"
    end

    # dump screens to /tmp. Implies {#demo} .
    # See installation/Test-Scripts/yast2-screen-shots*
    def screen_shot
      testMode == "screenshot"
    end

    # Returns whether running in testsuite.
    def testsuite
      testMode == "testsuite"
    end

    # UI mode wrappers

    # we're running in command line interface
    # @return true if command-line is running
    def commandline
      ui == "commandline"
    end

    publish :function => :Initialize, :type => "void ()"
    publish :function => :mode, :type => "string ()"
    publish :function => :SetMode, :type => "void (string)"
    publish :function => :commandline, :type => "boolean ()"
    publish :function => :testMode, :type => "string ()"
    publish :function => :SetTest, :type => "void (string)"
    publish :function => :ui, :type => "string ()"
    publish :function => :SetUI, :type => "void (string)"
    publish :function => :installation, :type => "boolean ()"
    publish :function => :live_installation, :type => "boolean ()"
    publish :function => :update, :type => "boolean ()"
    publish :function => :Depeche, :type => "boolean ()"
    publish :function => :normal, :type => "boolean ()"
    publish :function => :repair, :type => "boolean ()"
    publish :function => :autoinst, :type => "boolean ()"
    publish :function => :autoupgrade, :type => "boolean ()"
    publish :function => :config, :type => "boolean ()"
    publish :function => :test, :type => "boolean ()"
    publish :function => :screen_shot, :type => "boolean ()"
    publish :function => :testsuite, :type => "boolean ()"
  end

  Mode = ModeClass.new
  Mode.main
end
