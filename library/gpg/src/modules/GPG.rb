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
# File:	modules/GPG.ycp
# Package:	yast2
# Summary:	A wrapper for gpg binary
# Authors:	Ladislav Slezák <lslezak@suse.cz>
#
# $Id$
#
# This module provides GPG key related functions. It is a wrapper around gpg
# binary. It uses caching for reading GPG keys from the keyrings.
require "yast"

module Yast
  class GPGClass < Module
    def main
      Yast.import "UI"

      Yast.import "String"
      Yast.import "Report"
      Yast.import "FileUtils"

      textdomain "base"

      # value for --homedir gpg option, empty string means default home directory
      @home = ""

      # key cache
      @public_keys = nil
      # key cache
      @private_keys = nil

      # Map for parsing gpg output. Key is regexp, value is the key returned
      # in the result of the parsing.
      @parsing_map = {
        # secret key ID
        "^sec  .*/([^ ]*) "             => "id",
        # public key id
        "^pub  .*/([^ ]*) "             => "id",
        # user id
        "^uid *(.*)"                    => "uid",
        # fingerprint
        "^      Key fingerprint = (.*)" => "fingerprint"
      }
    end

    # (Re)initialize the module, the cache is invalidated if the home directory is changed.
    # @param [String] home_dir home directory for gpg (location of the keyring)
    # @param [Boolean] force unconditionaly clear the key caches
    def Init(home_dir, force)
      if home_dir != "" && FileUtils.IsDirectory(home_dir) != true
        Builtins.y2error("Path %1 is not a directory", home_dir)
        return false
      end

      if home_dir != @home || force
        # clear the cache, home has been changed
        @public_keys = nil
        @private_keys = nil
      end

      @home = home_dir

      true
    end

    # Build GPG option string
    # @param [String] options additional gpg options
    # @return [String] gpg option string
    def buildGPGcommand(options)
      home_opt = @home.empty? ? "" : "--homedir '#{String.Quote(@home)}' "
      ret = "gpg #{home_opt} #{options}"
      Builtins.y2milestone("gpg command: %1", ret)

      ret
    end

    # Execute gpg with the specified parameters, --homedir is added to the options
    # @param [String] options additional gpg options
    # @return [Hash] result of the execution
    def callGPG(options)
      command = Ops.add("LC_ALL=en_US.UTF-8 ", buildGPGcommand(options))

      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      if Ops.get_integer(ret, "exit", -1) != 0
        Builtins.y2error("gpg error: %1", ret)
      end

      deep_copy(ret)
    end

    # Parse gpg output using the parsing map
    # @param [Array<String>] lines gpg output (splitted into lines)
    # @return [Hash] parsed output
    def parse_key(lines)
      lines = deep_copy(lines)
      ret = {}

      Builtins.foreach(lines) do |line|
        Builtins.foreach(@parsing_map) do |regexp, key|
          parsed = Builtins.regexpsub(line, regexp, "\\1")
          if !parsed.nil?
            # there might be more UIDs
            if key == "uid"
              Builtins.y2milestone("%1: %2", key, parsed)
              Ops.set(ret, key, Builtins.add(Ops.get_list(ret, key, []), parsed))
            else
              if Builtins.haskey(ret, key)
                Builtins.y2warning(
                  "Key %1: replacing old value '%2' with '%3'",
                  key,
                  Ops.get_string(ret, key, ""),
                  parsed
                )
              end
              Ops.set(ret, key, parsed)
            end
          end
        end
      end

      Builtins.y2milestone("Parsed key: %1", ret)

      deep_copy(ret)
    end

    # Parse gpg output
    # @param [String] input gpg output
    # @return [Array<Hash>] parsed keys
    def parseKeys(input)
      # note: see /usr/share/doc/packages/gpg/DETAILS for another way

      ret = []
      lines = Builtins.splitstring(input, "\n")

      if Ops.greater_than(Builtins.size(input), 2)
        # remove the header
        lines = Builtins.remove(lines, 0)
        lines = Builtins.remove(lines, 0)
      end

      key_lines = []
      key_line_list = []

      # create groups
      Builtins.foreach(lines) do |line|
        if line == ""
          key_lines = Builtins.add(key_lines, key_line_list)
          key_line_list = []
        else
          key_line_list = Builtins.add(key_line_list, line)
        end
      end

      # parse each group to map
      Builtins.foreach(key_lines) do |keylines|
        parsed = parse_key(keylines)
        if Ops.greater_than(Builtins.size(parsed), 0)
          ret = Builtins.add(ret, parsed)
        end
      end

      Builtins.y2milestone("Parsed keys: %1", ret)

      deep_copy(ret)
    end

    # Return list of the public keys in the keyring.
    # @return [Array<Hash> public keys: [ $["fingerprint": String key_fingerprint, "id": String key_ID, "uid": Array<String>] user_ids], ...]
    def PublicKeys
      # return the cached values if available
      return deep_copy(@public_keys) if !@public_keys.nil?

      out = callGPG("--list-keys --fingerprint")

      if Ops.get_integer(out, "exit", -1) == 0
        @public_keys = parseKeys(Ops.get_string(out, "stdout", ""))
      end

      deep_copy(@public_keys)
    end

    # Return list of the private keys in the keyring.
    # @return [Array<Hash> public keys: [ $["fingerprint": String key_fingerprint, "id": String key_ID, "uid": Array<String>] user_ids], ...]
    def PrivateKeys
      # return the cached values if available
      return deep_copy(@private_keys) if !@private_keys.nil?

      out = callGPG("--list-secret-keys --fingerprint")

      if Ops.get_integer(out, "exit", -1) == 0
        @private_keys = parseKeys(Ops.get_string(out, "stdout", ""))
      end

      deep_copy(@private_keys)
    end

    # Create a new gpg key. Executes 'gpg --gen-key' in an xterm window (in the QT UI)
    # or in the terminal window (in the ncurses UI).
    def CreateKey
      xterm = "/usr/bin/xterm"
      command = Ops.add("GPG_AGENT_INFO='' ", buildGPGcommand("--gen-key"))
      text_mode = Ops.get_boolean(UI.GetDisplayInfo, "TextMode", false)

      Builtins.y2debug("text_mode: %1", text_mode)

      ret = false

      if !text_mode
        if Ops.less_than(SCR.Read(path(".target.size"), xterm), 0)
          # FIXME: do it
          Report.Error(_("Xterm is missing, install xterm package."))
          return false
        end

        exit_file = Ops.add(
          Convert.to_string(SCR.Read(path(".target.tmpdir"))),
          "/gpg_tmp_exit_file"
        )
        if FileUtils.Exists(exit_file)
          SCR.Execute(path(".target.bash"), Ops.add("rm -f ", exit_file))
        end

        command = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(Ops.add("LC_ALL=en_US.UTF-8 ", xterm), " -e \""),
                command
              ),
              "; echo $? > "
            ),
            exit_file
          ),
          "\""
        )
        Builtins.y2internal("Executing: %1", command)

        # in Qt start GPG in a xterm window
        SCR.Execute(path(".target.bash"), command)

        if FileUtils.Exists(exit_file)
          # read the exit code from file
          # (the exit code from the SCR call above is the xterm exit code which is not what we want here)
          exit_code = Convert.to_string(
            SCR.Read(path(".target.string"), exit_file)
          )
          Builtins.y2milestone(
            "Read exit code from tmp file %1: %2",
            exit_file,
            exit_code
          )

          ret = exit_code == "0\n"
        else
          Builtins.y2warning("Exit file is missing, the gpg command has failed")
          ret = false
        end
      else
        command = Ops.add("LC_ALL=en_US.UTF-8 ", command)
        Builtins.y2internal("Executing in terminal: %1", command)
        # in ncurses use UI::RunInTerminal
        ret = UI.RunInTerminal(command) == 0
      end

      if ret
        # invalidate cache, force reloading
        Init(@home, true)
      end

      ret
    end

    # Sign a file. The ASCII armored signature is stored in file with .asc suffix
    # @param [String] keyid id of the signing key
    # @param [String] file the file to sign
    # @param [String] passphrase passphrase to unlock the private key
    # @param [Boolean] ascii_signature if true ASCII armored signature is created
    #        (with suffix .asc) otherwise binary signature (with suffix .sig) is created
    # @return [Boolean] true if the file has been successfuly signed
    def SignFile(keyid, file, passphrase, ascii_signature)
      if passphrase.nil? || keyid.nil? || keyid == "" || file.nil? ||
          file == ""
        Builtins.y2error(
          "Invalid parameters: keyid: %1, file: %2, passphrase: %3",
          keyid,
          file,
          passphrase
        )
        return false
      end

      # signature suffix depends on the format
      suffix = ascii_signature ? ".asc" : ".sig"

      if Ops.greater_or_equal(
        Convert.to_integer(
          SCR.Read(path(".target.size"), Ops.add(file, suffix))
        ),
        0
      )
        # remove the existing key
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("rm -f '%1%2'", String.Quote(file), suffix)
        )
      end

      # save the passphrase to a file
      tmpfile = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/stdin"
      )

      written = SCR.Write(
        path(".target.string"),
        tmpfile,
        Ops.add(passphrase, "\n")
      )

      return false if !written

      # use the passphrase
      out = callGPG(
        Builtins.sformat(
          "--detach-sign -u '%1' --no-tty --batch --command-fd=0 --passphrase-fd 0 %2 '%3' < '%4'",
          String.Quote(keyid),
          ascii_signature ? "-a" : "",
          String.Quote(file),
          String.Quote(tmpfile)
        )
      )

      Ops.get_integer(out, "exit", -1) == 0
    end

    # Sign a file. The ASCII armored signature is stored in file with .asc suffix
    # @param [String] keyid id of the signing key
    # @param [String] file the file to sign
    # @param [String] passphrase passphrase to unlock the private key
    # @return [Boolean] true if the file has been successfuly signed
    def SignAsciiDetached(keyid, file, passphrase)
      SignFile(keyid, file, passphrase, true)
    end

    # Sign a file. The binary signature is stored in file with .sig suffix
    # @param [String] keyid id of the signing key
    # @param [String] file the file to sign
    # @param [String] passphrase passphrase to unlock the private key
    # @return [Boolean] true if the file has been successfuly signed
    def SignDetached(keyid, file, passphrase)
      SignFile(keyid, file, passphrase, false)
    end

    # Verify a file using a signature file. The key which has been used for signing must be imported in the keyring.
    # @param [String] sig_file file with the signature
    # @param [String] file file to verify
    # @return [Boolean] true if the file has been successfuly verified
    def VerifyFile(sig_file, file)
      out = callGPG(
        Builtins.sformat(
          "--verify '%1' '%2'",
          String.Quote(sig_file),
          String.Quote(file)
        )
      )

      Ops.get_integer(out, "exit", -1) == 0
    end

    # Export a public gpg key in ACSII armored file.
    # @param [String] keyid id of the key
    # @param [String] file the target file
    # @return [Boolean] true if the file has been successfuly signed
    def ExportAsciiPublicKey(keyid, file)
      out = callGPG(
        Builtins.sformat(
          "-a --export '%1' > '%2'",
          String.Quote(keyid),
          String.Quote(file)
        )
      )

      Ops.get_integer(out, "exit", -1) == 0
    end

    # Export a public gpg key in binary format.
    # @param [String] keyid id of the key
    # @param [String] file the target file
    # @return [Boolean] true if the file has been successfuly signed
    def ExportPublicKey(keyid, file)
      out = callGPG(
        Builtins.sformat(
          "--export '%1' > '%2'",
          String.Quote(keyid),
          String.Quote(file)
        )
      )

      Ops.get_integer(out, "exit", -1) == 0
    end

    publish function: :Init, type: "boolean (string, boolean)"
    publish function: :PublicKeys, type: "list <map> ()"
    publish function: :PrivateKeys, type: "list <map> ()"
    publish function: :CreateKey, type: "boolean ()"
    publish function: :SignAsciiDetached, type: "boolean (string, string, string)"
    publish function: :SignDetached, type: "boolean (string, string, string)"
    publish function: :VerifyFile, type: "boolean (string, string)"
    publish function: :ExportAsciiPublicKey, type: "boolean (string, string)"
    publish function: :ExportPublicKey, type: "boolean (string, string)"
  end

  GPG = GPGClass.new
  GPG.main
end
