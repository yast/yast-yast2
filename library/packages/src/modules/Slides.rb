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
# Module:		Slides.ycp
#
# Purpose:		Module to access slides from installation repository
#
# Author:		Stefan Hundhammer <sh@suse.de>
#                      Stanislav Visnovsky <visnov@suse.cz>
#
require "yast"

module Yast
  class SlidesClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "FileUtils"
      Yast.import "Installation"

      # list of currently known slides, in the order they should be shown
      @slides = []
      # base path to look for slides
      @slide_base_path = Ops.add(Installation.sourcedir, "/suse/setup/slide")
      # path to look for texts of slides
      @slide_txt_path = ""
      # path to look for images of slides
      @slide_pic_path = ""
      # if no other language is configured, use this fallback
      @fallback_lang = "en"
    end

    # Get a list of available slides (images) for the slide show.
    # @param [String] lang language of slides to load
    # @return [Array] slides
    #
    def GetSlideList(lang)
      slide_list = nil

      txt_path = Builtins.sformat("%1/txt/%2", @slide_base_path, lang)
      if FileUtils.Exists(txt_path)
        slide_list = Convert.convert(
          SCR.Read(path(".target.dir"), txt_path),
          from: "any",
          to:   "list <string>"
        )
      end

      if slide_list == nil
        Builtins.y2error("Directory %1 does not exist", txt_path)
        if Ops.greater_than(Builtins.size(lang), 2)
          lang = Builtins.substring(lang, 0, 2)
          txt_path = Builtins.sformat("%1/txt/%2", @slide_base_path, lang)

          if FileUtils.Exists(txt_path)
            slide_list = Convert.convert(
              SCR.Read(path(".target.dir"), txt_path),
              from: "any",
              to:   "list <string>"
            )
          end
        end
      end

      if slide_list == nil
        Builtins.y2milestone("Slideshow directory %1 does not exist", txt_path)
      else
        Builtins.y2milestone(
          "Using slides from '%1' (%2 slides)",
          txt_path,
          Builtins.size(slide_list)
        )

        slide_list = Builtins.sort(Builtins.filter(slide_list) do |filename|
          Builtins.regexpmatch(filename, ".*.(rtf|RTF|html|HTML|htm|HTM)$")
        end)

        Builtins.y2debug(
          "GetSlideList(): Slides at %1: %2",
          txt_path,
          slide_list
        )
      end

      if slide_list != nil && Ops.greater_than(Builtins.size(slide_list), 0) # Slide texts found
        @slide_txt_path = txt_path
        @slide_pic_path = Ops.add(@slide_base_path, "/pic")

        Builtins.y2milestone(
          "Using TXT: %1, PIC: %2",
          @slide_txt_path,
          @slide_pic_path
        ) # No slide texts found
      else
        Builtins.y2debug("No slides found at %1", txt_path)

        # function calls itself!
        if lang != @fallback_lang
          Builtins.y2debug(
            "Trying to load slides from fallback: %1",
            @fallback_lang
          )
          slide_list = GetSlideList(@fallback_lang)
        end
      end

      deep_copy(slide_list)
    end

    # Check if showing slides is supported.
    #
    # Not to be confused with HaveSlides() which checks if there are slides available.
    # @return [Boolean] if the current UI is capable of showing slides
    #
    def HaveSlideSupport
      disp = UI.GetDisplayInfo

      if disp != nil && # This shouldn't happen, but who knows?
          Ops.get_boolean(disp, "HasImageSupport", false) &&
          Ops.greater_or_equal(Ops.get_integer(disp, "DefaultWidth", -1), 800) &&
          Ops.greater_or_equal(Ops.get_integer(disp, "DefaultHeight", -1), 600) &&
          Ops.greater_or_equal(Ops.get_integer(disp, "Depth", -1), 8)
        return true
      else
        return false
      end
    end

    # Check if slides are available.
    #
    # Not to be confused with HaveSlideSupport() which checks
    # if slides could be displayed if there are any.
    # @return [Boolean] if the loaded list of slides contains any slides
    #
    def HaveSlides
      Ops.greater_than(Builtins.size(@slides), 0)
    end

    # Load one slide from files complete with image and textual description.
    # Also adapt img links
    # @param [String] slide_name name of the slide
    # @return true if OK, false if error
    #
    def LoadSlideFile(slide_name)
      text_file_name = Builtins.sformat("%1/%2", @slide_txt_path, slide_name)
      # returns empty string if not found
      text = Convert.to_string(
        SCR.Read(path(".target.string"), [text_file_name, ""])
      )

      #
      # Fix <img src> tags: Replace image path with current slide_pic_path
      #
      loop do
        replaced = Builtins.regexpsub(
          text,
          "(.*)&imagedir;(.*)",
          Builtins.sformat("\\1%1\\2", @slide_pic_path)
        )
        break if replaced == nil
        text = replaced
      end

      text
    end

    # Set the slide show directory
    def SetSlideDir(dir)
      @slide_base_path = dir

      tmp = Convert.to_map(WFM.Read(path(".local.stat"), @slide_base_path))

      if !Ops.get_boolean(tmp, "isdir", false)
        Builtins.y2error("Using default path instead of %1", tmp)
        @slide_base_path = "/var/adm/YaST/InstSrcManager/tmp/CurrentMedia/suse/setup/slide"
      end

      Builtins.y2milestone("SetSlideDir: %1", @slide_base_path)

      nil
    end

    # Load slides for the given language and store them in the internal variables.
    # @param [String] language requested language of the slides
    def LoadSlides(language)
      @slides = GetSlideList(language)

      nil
    end

    # Check, if the base path set up for slides is valid (it exists and contains slides)
    # @return [Boolean] true, if it is possible to load the slides
    def CheckBasePath
      tmp = Convert.to_map(WFM.Read(path(".local.stat"), @slide_base_path))
      if !Ops.get_boolean(tmp, "isdir", false)
        Builtins.y2error("Using default path instead of %1", @slide_base_path)
        @slide_base_path = "/var/adm/YaST/InstSrcManager/tmp/CurrentMedia/suse/setup/slide"

        return false
      end
      true
    end

    publish variable: :slides, type: "list <string>"
    publish variable: :slide_base_path, type: "string"
    publish variable: :slide_txt_path, type: "string"
    publish variable: :slide_pic_path, type: "string"
    publish variable: :fallback_lang, type: "string"
    publish function: :HaveSlideSupport, type: "boolean ()"
    publish function: :HaveSlides, type: "boolean ()"
    publish function: :LoadSlideFile, type: "string (string)"
    publish function: :SetSlideDir, type: "void (string)"
    publish function: :LoadSlides, type: "void (string)"
    publish function: :CheckBasePath, type: "boolean ()"
  end

  Slides = SlidesClass.new
  Slides.main
end
