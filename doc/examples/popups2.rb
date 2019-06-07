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
# Advanced popups example
#
# Author: Stefan Hundhammer <sh@suse.de>
#
# $Id$
module Yast
  class Popups2Client < Client
    def main
      Yast.import "UI"
      Yast.import "Label"
      Yast.import "Popup"

      UI.OpenDialog(
        VBox(
          PushButton(
            Id(:yesNo),
            Opt(:hstretch),
            "&Yes / No popup with headline "
          ),
          PushButton(Id(:generic2), Opt(:hstretch), "&Generic 2-button-popup"),
          PushButton(Id(:generic3), Opt(:hstretch), "&Generic 3-button-popup"),
          PushButton(Id(:longText), Opt(:hstretch), "&Long text popup"),
          VSpacing(),
          PushButton(Id(:close), Label.CloseButton)
        )
      )

      @button_id = :dummy
      loop do
        @button_id = Convert.to_symbol(UI.UserInput)

        case @button_id
        when :yesNo
          Popup.YesNoHeadline(
            "Really delete world?",
            "You in your infinite wisdom have chosen to delete this only world of ours.\n" \
              "This will mean the end to all of mankind and all life in the only known planet\n" \
              "known to be inhabited by intelligent or other life in the entire universe.\n" \
              "\n" \
              "Even though it is well known that mankind and human character are far from perfect,\n" \
              "we urgently request you to reconsider that decision.\n" \
              "\n" \
              "Are you absolutely sure you wish to delete this world?"
          )
        when :generic2
          Popup.AnyQuestion(
            "Great Dilemma",
            "You must now decide how to save the world.\n" \
              "\n" \
              "\n" \
              "\n" \
              "If you make the wrong decision, creatures from outer space may choose\n" \
              "\n" \
              "to get rid of this planet of ours to make room for some interstellar\n" \
              "\n" \
              "hyper expressway.\n" \
              "\n" \
              "\n" \
              "\n" \
              "So: Do you fail to recognize that your inability to confront\n" \
             "\n" \
              "this kind of indecision may destroy all of mankind?",
            "&Everything you say",
            "I'll &buy one of it",
            :focus_no
          )
        when :generic3
          Popup.AnyQuestion3(
            "Greatest Dilemma of the Millennium",
            "You must now decide how to save the world.\n" \
              "\n" \
              "\n" \
              "\n" \
              "If you make the wrong decision, creatures from outer space may choose\n" \
              "\n" \
              "to get rid of this planet of ours to make room for some interstellar\n" \
              "\n" \
              "hyper expressway.\n" \
              "\n" \
              "\n" \
              "\n" \
              "So: Do you fail to recognize that your inability to confront\n" \
             "\n" \
              "this kind of indecision may destroy all of mankind?",
            "&Everything you say",
            "I'll &buy one of it",
            "But I don't have a &car",
            :focus_no
          )
        when :longText
          Popup.LongText(
            "Bad News",
            RichText(
              "<p>Due to unforeseen circumstances it is necessary to <b>format your hard disk</b>.</p>\n" \
                "<p>This may sound bad enough, but we must <b>format your brain</b>, too.</p>\n" \
                "<p>And once this is done, you will fail to notice that in the process\n" \
                "the entire planet will undergo substantial <b>rearranging of the continental shelves</b>:\n" \
                "The continents will all be lowered to eight feet below sea level.</p>\n"
            ),
            50, # width
            10
          ) # height
        when :close
          break
        end
      end

      UI.CloseDialog

      nil
    end
  end
end

Yast::Popups2Client.new.main
