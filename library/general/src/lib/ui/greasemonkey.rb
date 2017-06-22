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

# File:	Greasemonkey.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
#
# Lets see if this turns out to be useful.
require "yast"

module UI
  # UI layout helpers.
  #
  # rubocop:disable Metrics/ModuleLength
  module Greasemonkey
    include Yast
    extend Yast
    include Yast::UIShortcuts
    extend Yast::UIShortcuts

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

    def VStackFrames(old)
      old = deep_copy(old)
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

      deep_copy(new)
    end
    module_function :VStackFrames

    def FrameWithMarginBox(old)
      old = deep_copy(old)
      title = Ops.get_string(old, 0, "error")
      args = Builtins.sublist(Builtins.argsof(old), 1)
      Frame(
        title,
        Builtins.toterm(:MarginBox, Builtins.union([1.45, 0.45], args))
      )
    end
    module_function :FrameWithMarginBox

    # ComboBoxSelected
    #
    # `ComboBoxSelected(`id(`wish), `opt(`notify), "Wish",
    #                   [ `item(`id(`time), "Time"),
    #                     `item(`id(`love), "Love"),
    #                     `item(`id(`money), "Money") ],
    #                   `id(`love))
    #
    # `ComboBox(`id(`wish), `opt(`notify), "Wish",
    #           [ `item(`id(`time), "Time", false),
    #             `item(`id(`love), "Love", true),
    #             `item(`id(`money), "Money", false) ])
    def ComboBoxSelected(old)
      old = deep_copy(old)
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

    # LeftRadioButton
    #
    # `LeftRadioButton(`id(), `opt(), "text")
    #
    # `Left(`RadioButton(`id(), `opt(), "text"))
    def LeftRadioButton(old)
      old = deep_copy(old)
      Left(Builtins.toterm(:RadioButton, Builtins.argsof(old)))
    end
    module_function :LeftRadioButton

    # LeftRadioButtonWithAttachment
    #
    # `LeftRadioButtonWithAttachment(`id(), `opt(), "text", contents)
    #
    # `VBox(
    #    `Left(`Radiobutton(`id(), `opt(), "text")),
    #    `HBox(`HSpacing(4), contents)
    # )
    def LeftRadioButtonWithAttachment(old)
      old = deep_copy(old)
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

    # LeftCheckBox
    #
    # `LeftCheckBox(`id(), `opt(), "text")
    #
    # `Left(`CheckBox(`id(), `opt(), "text"))
    def LeftCheckBox(old)
      old = deep_copy(old)
      Left(Builtins.toterm(:CheckBox, Builtins.argsof(old)))
    end
    module_function :LeftCheckBox

    # LeftCheckBoxWithAttachment
    #
    # `LeftCheckBoxWithAttachment(`id(), `opt(), "text", contents)
    #
    # `VBox(
    #    `Left(`Radiobutton(`id(), `opt(), "text")),
    #    `HBox(`HSpacing(4), contents)
    # )
    def LeftCheckBoxWithAttachment(old)
      old = deep_copy(old)
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

    # IconAndHeading
    #
    # `IconAndHeading("title", "icon")
    #
    # `Left(`HBox(`Image("icon", ""),
    #             `Heading("title")));
    def IconAndHeading(old)
      old = deep_copy(old)
      args = Builtins.argsof(old)

      title = Ops.get_string(args, 0, "")
      icon = Ops.add(
        Ops.add(Directory.icondir, "22x22/apps/"),
        Ops.get_string(args, 1, "")
      )

      Left(HBox(Image(icon, ""), Heading(title)))
    end
    module_function :IconAndHeading

    def Transform(old)
      old = deep_copy(old)
      s = Builtins.symbolof(old)

      handler = Greasemonkey.method(s) if @handlers.include?(s)
      return Transform(handler.call(old)) if !handler.nil?

      new = Builtins::List.reduce(Builtins.toterm(s), Builtins.argsof(old)) do |tmp, arg|
        arg = Transform(Convert.to_term(arg)) if Ops.is_term?(arg)
        Builtins.add(tmp, arg)
      end

      deep_copy(new)
    end
    module_function :Transform

    alias_method :transform, :Transform
    module_function :transform
  end
end
