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
# File:    modules/DontShowAgain.ycp
# Authors: Lukas Ocilka <locilka@suse.cz>
# Summary: Handling "Don Not Show This Dialog Again"
#
# $Id: DontShowAgain.ycp 11111 2006-05-29 12:27:15Z locilka $
require "yast"

module Yast
  class DontShowAgainClass < Module
    def main
      textdomain "base"

      Yast.import "Directory"
      Yast.import "FileUtils"

      # Module for that stores and returns the information for
      # "Don't Show This Dialog/Question Again"

      # File with the current configuration
      @conf_file = Ops.add(Directory.vardir, "/dont_show_again.conf")

      # Current configuration map
      #
      #
      # **Structure:**
      #
      #     $[
      #          // question type
      #          "inst-source" : $[
      #              // question identification (MD5sum of the question in the future?)
      #              "-question-ident-" : $[
      #                  // url of the file or directory
      #                  "ftp://abc.xyz/rtf" : $[
      #                      // show the dialog again
      #                      "show_again" : false,
      #                      // additional question return
      #                      "return" : true,
      #                  ]
      #              ]
      #          ]
      #      ]
      @current_configuration = {}

      # Configuration has already been read
      @already_read = false
    end

    # Function that reads the current configuration if it hasn't been
    # read already. It must be called before every Get or Set command.
    def LazyLoadCurrentConf
      if !@already_read
        if FileUtils.Exists(@conf_file) && FileUtils.IsFile(@conf_file)
          Builtins.y2milestone("Reading %1 file", @conf_file)
          # Read and evaluate the current configuration
          read_conf = Convert.convert(
            SCR.Read(path(".target.ycp"), @conf_file),
            from: "any",
            to:   "map <string, map <string, map <string, any>>>"
          )
          @current_configuration = deep_copy(read_conf) if !read_conf.nil?
        else
          Builtins.y2milestone(
            "Configuration file %1 doesn't exist, there's no current configuration.",
            @conf_file
          )
        end

        # Configuration mustn't be read again
        @already_read = true
      end

      nil
    end

    # Saves  the current configuration into the configuration file
    def SaveCurrentConfiguration
      LazyLoadCurrentConf()

      # Removing nil entries from the configuration
      new_configuration = {}

      Builtins.foreach(@current_configuration) do |dont_show_type, records|
        # Defined and known type
        if dont_show_type == "inst-source"
          # Every popup type
          Builtins.foreach(records) do |popup_type, one_record|
            # Every URL
            Builtins.foreach(one_record) do |url, record_options|
              # Record mustn't be nil or empty to be reused
              if !record_options.nil? && record_options != {}
                # Creating map from the base
                if Ops.get(new_configuration, dont_show_type).nil?
                  Ops.set(new_configuration, dont_show_type, {})
                end
                if Ops.get(new_configuration, [dont_show_type, popup_type]).nil?
                  Ops.set(new_configuration, [dont_show_type, popup_type], {})
                end

                Ops.set(
                  new_configuration,
                  [dont_show_type, popup_type, url],
                  record_options
                )
              end
            end
          end
          # Unknown type
        else
          Ops.set(new_configuration, dont_show_type, records)
        end
      end

      @current_configuration = deep_copy(new_configuration)

      SCR.Write(path(".target.ycp"), @conf_file, @current_configuration)
    end

    # Returns whether the question should be shown again
    #
    # @param map <string, string> of params
    # @see #current_configuration
    # @return [Boolean] it should be shown
    def GetShowQuestionAgain(params)
      params = deep_copy(params)
      LazyLoadCurrentConf()
      q_type = Ops.get(params, "q_type")

      # <--- repositories --->
      # Parameters, $[
      #     "q_type"  : "inst-source",             // mandatory
      #     "q_ident" : "Question Identification", // mandatory
      #     "q_url" : "URL"                        // optional
      # ];
      if q_type == "inst-source"
        q_ident = Ops.get(params, "q_ident")
        q_url = Ops.get(params, "q_url")

        if q_ident.nil?
          Builtins.y2error("'q_ident' is a mandatory parameter")
          return nil
        end

        if Ops.get(@current_configuration, q_type).nil? ||
            Ops.get(@current_configuration, [q_type, q_ident]).nil? ||
            Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil? ||
            Ops.get(
              @current_configuration,
              [q_type, q_ident, q_url, "show_again"]
            ).nil?
          return nil
        end

        return Ops.get_boolean(
          @current_configuration,
          [q_type, q_ident, q_url, "show_again"]
        )
        # <--- repositories --->

        # Add another types here...
      else
        Builtins.y2error("'%1' is an unknown type", q_type)
        return nil
      end
    end

    # Sets and stores whether the question should be shown again.
    # If it should be, the result is not stored since the 'show again'
    # is the default value.
    #
    # @param map <string, string> of params
    # @see #current_configuration
    # @param boolean show again
    # @return [Boolean] if success
    def SetShowQuestionAgain(params, new_value)
      params = deep_copy(params)
      LazyLoadCurrentConf()
      q_type = Ops.get(params, "q_type")
      # Always set to 'true' if the configuration is changed
      conf_changed = false

      # <--- repositories --->
      # Parameters, $[
      #     "q_type"  : "inst-source",             // mandatory
      #     "q_ident" : "Question Identification", // mandatory
      #     "q_url" : "URL"                        // optional
      # ];
      if q_type == "inst-source"
        q_ident = Ops.get(params, "q_ident")
        q_url = Ops.get(params, "q_url")

        if q_ident.nil?
          Builtins.y2error("'q_ident' is a mandatory parameter")
          return nil
        end

        # building the configuration map
        if Ops.get(@current_configuration, q_type).nil?
          Ops.set(@current_configuration, q_type, {})
        end
        if Ops.get(@current_configuration, [q_type, q_ident]).nil?
          Ops.set(@current_configuration, [q_type, q_ident], {})
        end
        if Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil?
          Ops.set(@current_configuration, [q_type, q_ident, q_url], {})
        end

        # save the new value into the configuration
        conf_changed = true
        Ops.set(
          @current_configuration,
          [q_type, q_ident, q_url, "show_again"],
          new_value
        )
        # <--- repositories --->

        # Add another types here...
      else
        Builtins.y2error("'%1' is an unknown type", q_type)
        return nil
      end

      conf_changed ? SaveCurrentConfiguration() : nil
    end

    # Return the default return value for question that should not
    # be shown again
    #
    # @param map <string, string> of params
    # @see #current_configuration
    # @return [Object] default return value
    def GetDefaultReturn(params)
      params = deep_copy(params)
      LazyLoadCurrentConf()
      q_type = Ops.get(params, "q_type")

      # <--- repositories --->
      # Parameters, $[
      #     "q_type"  : "inst-source",             // mandatory
      #     "q_ident" : "Question Identification", // mandatory
      #     "q_url" : "URL"                        // optional
      # ];
      # <--- repositories --->
      if q_type == "inst-source"
        q_ident = Ops.get(params, "q_ident")
        q_url = Ops.get(params, "q_url")

        if Ops.get(@current_configuration, q_type).nil? ||
            Ops.get(@current_configuration, [q_type, q_ident]).nil? ||
            Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil? ||
            Ops.get(@current_configuration, [q_type, q_ident, q_url, "return"]).nil?
          return nil
        end

        return Ops.get(
          @current_configuration,
          [q_type, q_ident, q_url, "return"]
        )

        # Add another types here...
      else
        Builtins.y2error("'%1' is an unknown type", q_type)
        return nil
      end
      # <--- repositories --->
    end

    # Sets the default return value for the question that should not be shown
    #
    # @param map <string, string> of params
    # @param any default return
    # @see #current_configuration
    # @return [Boolean] if success
    def SetDefaultReturn(params, default_return)
      params = deep_copy(params)
      default_return = deep_copy(default_return)
      LazyLoadCurrentConf()
      q_type = Ops.get(params, "q_type")
      # Always set to 'true' if the configuration is changed
      conf_changed = false

      # <--- repositories --->
      # Parameters, $[
      #     "q_type"  : "inst-source",             // mandatory
      #     "q_ident" : "Question Identification", // mandatory
      #     "q_url" : "URL"                        // optional
      # ];
      if q_type == "inst-source"
        q_ident = Ops.get(params, "q_ident")
        q_url = Ops.get(params, "q_url")

        if q_ident.nil?
          Builtins.y2error("'q_ident' is a mandatory parameter")
          return nil
        end

        # building the configuration map
        if Ops.get(@current_configuration, q_type).nil?
          Ops.set(@current_configuration, q_type, {})
        end
        if Ops.get(@current_configuration, [q_type, q_ident]).nil?
          Ops.set(@current_configuration, [q_type, q_ident], {})
        end
        if Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil?
          Ops.set(@current_configuration, [q_type, q_ident, q_url], {})
        end

        # save the new value into the configuration
        conf_changed = true
        Ops.set(
          @current_configuration,
          [q_type, q_ident, q_url, "return"],
          default_return
        )
        # <--- repositories --->

        # Add another types here...
      else
        Builtins.y2error("'%1' is an unknown type", q_type)
        return nil
      end

      conf_changed ? SaveCurrentConfiguration() : nil
    end

    # Returns the current configuration map
    #
    # @return [Hash <String, Hash <String, Hash{String => Object>} >] with the current configuration
    # @see #current_configuration
    def GetCurrentConfigurationMap
      LazyLoadCurrentConf()
      deep_copy(@current_configuration)
    end

    # Removes one entry defined with map params
    #
    # @param map <string, string> of params
    # @see #current_configuration
    # @return [Boolean] if success
    def RemoveShowQuestionAgain(params)
      params = deep_copy(params)
      LazyLoadCurrentConf()
      q_type = Ops.get(params, "q_type")

      if q_type == "inst-source"
        q_ident = Ops.get(params, "q_ident")
        q_url = Ops.get(params, "q_url")

        if !Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil?
          Ops.set(@current_configuration, [q_type, q_ident, q_url], nil)
          SaveCurrentConfiguration()
        end

        return Ops.get(@current_configuration, [q_type, q_ident, q_url]).nil?
      else
        Builtins.y2error("'%1' is an unknown type", q_type)
        return false
      end
    end

    publish variable: :already_read, type: "boolean"
    publish function: :GetShowQuestionAgain, type: "boolean (map <string, string>)"
    publish function: :SetShowQuestionAgain, type: "boolean (map <string, string>, boolean)"
    publish function: :GetDefaultReturn, type: "any (map <string, string>)"
    publish function: :SetDefaultReturn, type: "boolean (map <string, string>, any)"
    publish function: :GetCurrentConfigurationMap, type: "map <string, map <string, map <string, any>>> ()"
    publish function: :RemoveShowQuestionAgain, type: "boolean (map <string, string>)"
  end

  DontShowAgain = DontShowAgainClass.new
  DontShowAgain.main
end
