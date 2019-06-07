# typed: false
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
# File:	modules/UIHelper.ycp
# Package:	yast2
# Summary:	Set of helper modules for UI formatting
# Authors:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id: Version.ycp.in 10158 2003-06-23 12:48:40Z visnov $
require "yast"

module Yast
  class UIHelperClass < Module
    def main
      textdomain "base"
    end

    # Create an edit table with basic buttons.
    #
    # It contains table and buttons Add, Edit, Delete. User may specify table header
    # and content, content that will be placed above table, between table
    # and buttons, below buttons and rights from buttons (usually another
    # button).
    #
    # @param [Yast::Term] table_header Table header as defined in UI.
    # @param [Array] table_contents Table items.
    # @param [Yast::Term] above_table Content to place above table. There is no need to
    #    place caption here, because the dialog has its caption.
    #    Set it to nil if you do not want to place anything here.
    # @param [Yast::Term] below_table Contents to place between table and buttons.
    #    Set it to nil if you do not want to place anything here.
    # @param [Yast::Term] below_buttons Content to place below bottons.
    #    Set it to nil if you do not want to place anything here.
    # @param [Yast::Term] buttons Content to place rights from buttons. Usually
    #    an additional button, e.g. Set as default.
    #    Set it to nil if you do not want to place anything here.
    # @return Content for the `SetWizardContent[Buttons]()`
    # <B>UI elements ids:</B><table>
    # <tr><td>Table</td><td>`table</td></tr>
    # <tr><td>Button add</td><td>`add_button</td></tr>
    # <tr><td>Button edit</td><td>`edit_button</td></tr>
    # <tr><td>Button delete</td><td>`delete_button</td></tr>
    # </table>
    def EditTable(table_header, table_contents, above_table, below_table, below_buttons, buttons)
      table_header = deep_copy(table_header)
      table_contents = deep_copy(table_contents)
      above_table = deep_copy(above_table)
      below_table = deep_copy(below_table)
      below_buttons = deep_copy(below_buttons)
      buttons = deep_copy(buttons)
      contents = VBox()
      contents = Builtins.add(contents, above_table) if nil != above_table

      contents = Builtins.add(
        contents,
        Table(Id(:table), Opt(:notify), table_header, table_contents)
      )
      contents = Builtins.add(contents, below_table) if nil != below_table

      but_box = HBox(
        Opt(:hstretch),
        PushButton(Id(:add_button), Opt(:key_F3), _("A&dd")),
        PushButton(Id(:edit_button), Opt(:key_F4), _("&Edit")),
        PushButton(Id(:delete_button), Opt(:key_F5), _("De&lete"))
      )

      if nil != buttons
        but_box = Builtins.add(Builtins.add(but_box, HStretch()), buttons)
      end
      contents = Builtins.add(contents, but_box)
      contents = Builtins.add(contents, below_buttons) if nil != below_buttons
      deep_copy(contents)
    end

    # Encloses the content into VBoxes and HBoxes with the appropriate
    # spacings around it.
    # @param [Yast::Term] content The term we are adding spacing to.
    # @param [Float] left Spacing on the left.
    # @param [Float] right Spacing on the right.
    # @param [Float] top Spacing on the top.
    # @param [Float] bottom Spacing on the bottom.
    # @return Content with spacings around it.
    def SpacingAround(content, left, right, top, bottom)
      content = deep_copy(content)
      left = deep_copy(left)
      right = deep_copy(right)
      top = deep_copy(top)
      bottom = deep_copy(bottom)
      HBox(
        HSpacing(left),
        VBox(VSpacing(top), content, VSpacing(bottom)),
        HSpacing(right)
      )
    end

    # Encloses the content into VBoxes and HBoxes
    #
    # Enclose so that its
    # size is at least
    # <emphasis>xsize</emphasis>&nbsp;x&nbsp;<emphasis>ysize</emphasis>.
    # @param [Float] xsize Minimal size of content in the X direction
    # @param [Float] ysize Minimal size of content in the Y direction
    # @param [Yast::Term] content Content of the dialog
    # @return Contents sized at least <B>xsize</B>&nbsp;x&nbsp;<B>ysize</B>.
    def SizeAtLeast(content, xsize, ysize)
      content = deep_copy(content)
      xsize = deep_copy(xsize)
      ysize = deep_copy(ysize)
      VBox(
        VSpacing(0.4),
        HSpacing(xsize),
        HBox(HSpacing(1.6), VSpacing(ysize), content, HSpacing(1.6)),
        VSpacing(0.4)
      )
    end

    publish function: :EditTable, type: "term (term, list, term, term, term, term)"
    publish function: :SpacingAround, type: "term (term, float, float, float, float)"
    publish function: :SizeAtLeast, type: "term (term, float, float)"
  end

  UIHelper = UIHelperClass.new
  UIHelper.main
end
