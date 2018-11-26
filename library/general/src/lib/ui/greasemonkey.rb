# encoding: utf-8

# Copyright (c) 2012 Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"

module UI
  # UI layout helpers.
  #
  # These started out in the Expert Partitioner in yast2-storage.
  # The use case is reusing pieces of this legacy code in the new
  # yast2-partitioner.
  # That is why the API and the implementation look old.
  module Greasemonkey
    include Yast::UIShortcuts
    extend Yast::UIShortcuts

    Builtins = Yast::Builtins
    Convert = Yast::Convert
    Ops = Yast::Ops

    Yast.import "Directory"

    @handlers = [
      :VStackFrames,
      :FrameWithMarginBox,
      :ComboBoxSelected,
      :LeftRadioButton,
      :LeftRadioButtonWithAttachment,
      :LeftCheckBox,
      :LeftCheckBoxWithAttachment,
      :IconAndHeading
    ]

    # The compatibility API needs CamelCase method names
    # rubocop:disable MethodName

    # Wrap terms in a VBox with small vertical spacings in between.
    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(
    #     :VStackFrames,
    #     Frame("f1"),
    #     Frame("f2"),
    #     Frame("f3")
    #   )
    #     ->
    #   VBox(
    #     Frame("f1"),
    #     VSpacing(0.45),
    #     Frame("f2"),
    #     VSpacing(0.45),
    #     Frame("f3")
    #   )
    def VStackFrames(old)
      frames = Convert.convert(
        Builtins.argsof(old),
        from: "list",
        to:   "list <term>"
      )

      new = VBox()
      Builtins.foreach(frames) do |frame|
        new = Builtins.add(new, VSpacing(0.45)) if Builtins.size(new) != 0
        new = Builtins.add(new, frame)
      end
      new
    end
    module_function :VStackFrames

    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:FrameWithMarginBox, "Title", "arg1", "arg2")
    #      ->
    #   Frame("Title", MarginBox(1.45, 0.45, "arg1", "arg2"))
    def FrameWithMarginBox(old)
      title = Ops.get_string(old, 0, "error")
      args = Builtins.sublist(Builtins.argsof(old), 1)
      Frame(
        title,
        Builtins.toterm(:MarginBox, Builtins.union([1.45, 0.45], args))
      )
    end
    module_function :FrameWithMarginBox

    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(
    #     :ComboBoxSelected,
    #     Id(:wish), Opt(:notify), "Wish",
    #     [
    #       Item(Id(:time), "Time"),
    #       Item(Id(:love), "Love"),
    #       Item(Id(:money), "Money")
    #     ],
    #     Id(:love)
    #   )
    #     ->
    #   ComboBox(
    #     Id(:wish), Opt(:notify), "Wish",
    #     [
    #       Item(Id(:time), "Time", false),
    #       Item(Id(:love), "Love", true),
    #       Item(Id(:money), "Money", false)
    #     ]
    #   )
    def ComboBoxSelected(old)
      args = Builtins.argsof(old)

      tmp = Builtins.sublist(args, 0, Ops.subtract(Builtins.size(args), 2))
      items = Ops.get_list(args, Ops.subtract(Builtins.size(args), 2), [])
      id = Ops.get_term(args, Ops.subtract(Builtins.size(args), 1), Id())

      items = Builtins.maplist(items) do |item|
        Item(Ops.get(item, 0), Ops.get(item, 1), Ops.get(item, 0) == id)
      end

      Builtins.toterm(:ComboBox, Builtins.add(tmp, items))
    end
    module_function :ComboBoxSelected

    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:LeftRadioButton, Id(...), "args")
    #     ->
    #   Left(RadioButton(Id(...), "args"))
    def LeftRadioButton(old)
      Left(Builtins.toterm(:RadioButton, Builtins.argsof(old)))
    end
    module_function :LeftRadioButton

    # NOTE that it does not expand the nested
    # Greasemonkey term LeftRadioButton! {#transform} does that.
    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:LeftRadioButtonWithAttachment, "foo", "bar", "contents")
    #     ->
    #   VBox(
    #     term(:LeftRadioButton, "foo", "bar"),
    #     HBox(HSpacing(4), "contents")
    #   )
    def LeftRadioButtonWithAttachment(old)
      args = Builtins.argsof(old)

      tmp1 = Builtins.sublist(args, 0, Ops.subtract(Builtins.size(args), 1))
      tmp2 = Ops.get(args, Ops.subtract(Builtins.size(args), 1))

      if tmp2 == Empty() # rubocop:disable Style/GuardClause
        return VBox(Builtins.toterm(:LeftRadioButton, tmp1))
      else
        return VBox(
          Builtins.toterm(:LeftRadioButton, tmp1),
          HBox(HSpacing(4), tmp2)
        )
      end
    end
    module_function :LeftRadioButtonWithAttachment

    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:LeftCheckBox, Id(...), "args")
    #     ->
    #   Left(CheckBox(Id(...), "args"))
    def LeftCheckBox(old)
      Left(Builtins.toterm(:CheckBox, Builtins.argsof(old)))
    end
    module_function :LeftCheckBox

    # NOTE that it does not expand the nested
    # Greasemonkey term LeftCheckBox! {#transform} does that.
    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:LeftCheckBoxWithAttachment, "foo", "bar", "contents")
    #     ->
    #   VBox(
    #     term(:LeftCheckBox, "foo", "bar"),
    #     HBox(HSpacing(4), "contents")
    #   )
    def LeftCheckBoxWithAttachment(old)
      args = Builtins.argsof(old)

      tmp1 = Builtins.sublist(args, 0, Ops.subtract(Builtins.size(args), 1))
      tmp2 = Ops.get(args, Ops.subtract(Builtins.size(args), 1))

      if tmp2 == Empty() # rubocop:disable Style/GuardClause
        return VBox(Builtins.toterm(:LeftCheckBox, tmp1))
      else
        return VBox(
          Builtins.toterm(:LeftCheckBox, tmp1),
          HBox(HSpacing(4), tmp2)
        )
      end
    end
    module_function :LeftCheckBoxWithAttachment

    # @param old [Yast::Term]
    # @return    [Yast::Term]
    # @example
    #   term(:IconAndHeading, "title", "icon")
    #     ->
    #   Left(
    #     HBox(
    #       Image("/usr/share/YaST2/theme/current/icons/22x22/apps/icon", ""),
    #       Heading("title")
    #     )
    #   )
    def IconAndHeading(old)
      args = Builtins.argsof(old)

      title = Ops.get_string(args, 0, "")
      icon = Ops.get_string(args, 1, "")

      Left(HBox(Image(icon, ""), Heading(title)))
    end
    module_function :IconAndHeading

    # Recursively apply all Greasemonkey methods on *old*
    # @param old [Yast::Term]
    # @return    [Yast::Term]
    def Transform(old)
      s = Builtins.symbolof(old)

      handler = Greasemonkey.method(s) if @handlers.include?(s)
      return Transform(handler.call(old)) if !handler.nil?

      new = Builtins::List.reduce(Builtins.toterm(s), Builtins.argsof(old)) do |tmp, arg|
        arg = Transform(Convert.to_term(arg)) if Ops.is_term?(arg)
        Builtins.add(tmp, arg)
      end
      new
    end
    module_function :Transform

    alias_method :transform, :Transform
    module_function :transform
  end
end
