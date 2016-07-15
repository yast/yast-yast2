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
# Module:		SignatureCheckCallbacks.ycp
# Authors:		Lukas Ocilka <locilka@suse.cz>
#
# Callbacks for handling signatures.
#
# $Id: SignatureCheckCallbacks.ycp 28363 2006-02-24 12:27:15Z locilka $
require "yast"

module Yast
  class SignatureCheckCallbacksClass < Module
    include Yast::Logger

    def main
      textdomain "base"

      Yast.import "SignatureCheckDialogs"
      Yast.import "Pkg"

      # Default return when signatures shouldn't be checked
      # @see #SignatureCheckDialogs::CheckSignaturesInYaST()
      @default_return_unchecked = true
    end

    # ============================ < Callbacks for Repositories > ============================

    # Name of the callback handler function. Required callback prototype is
    # boolean(string filename). The callback function should ask user whether the
    # unsigned file can be accepted, returned true value means to accept the
    # file.
    #
    # zypp: askUserToAcceptUnsignedFile
    #
    # (+DontShowAgain functionality) -- for one run in memory
    #
    # function for CallbackAcceptUnsignedFile()
    def AcceptUnsignedFile(filename, repo_id)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      dont_show_dialog_ident = "-AcceptUnsignedFile-"

      # Show the popup?
      if SignatureCheckDialogs.GetShowThisPopup(
        dont_show_dialog_ident,
        filename
      )
        return SignatureCheckDialogs.UseUnsignedItem(
          :file,
          filename,
          dont_show_dialog_ident,
          repo_id
        )
        # Return the default value entered by user
      else
        return SignatureCheckDialogs.GetDefaultDialogReturn(
          dont_show_dialog_ident,
          filename
        )
      end
    end

    # Name of the callback handler function. Required callback prototype is
    # boolean(string filename) The callback function should ask user whether
    # the unsigned file can be accepted, returned true value means to accept the file.
    #
    # zypp: askUserToAcceptNoDigest
    #
    # (+DontShowAgain functionality) -- for one run in memory
    #
    # function for CallbackAcceptFileWithoutChecksum()
    def AcceptFileWithoutChecksum(filename)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      dont_show_dialog_ident = "-AcceptFileWithoutChecksum-"

      # Show the popup?
      if SignatureCheckDialogs.GetShowThisPopup(
        dont_show_dialog_ident,
        filename
      )
        return SignatureCheckDialogs.UseItemWithNoChecksum(
          :file,
          filename,
          dont_show_dialog_ident
        )
        # Return the default value entered by user
      else
        return SignatureCheckDialogs.GetDefaultDialogReturn(
          dont_show_dialog_ident,
          filename
        )
      end
    end

    # Callback handler function. Required callback prototype is <code>boolean(string filename, string requested_digest, string found_digest)</code>. The callback function should ask user whether the wrong digest can be accepted, returned true value means to accept the file.
    # @return [Boolean]
    # zypp: askUserToAcceptWrongDigest
    def AcceptWrongDigest(filename, requested_digest, found_digest)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      dont_show_dialog_ident = "-AcceptWrongDigest-"

      # Show the popup?
      if SignatureCheckDialogs.GetShowThisPopup(
        dont_show_dialog_ident,
        filename
      )
        return SignatureCheckDialogs.UseFileWithWrongDigest(
          filename,
          requested_digest,
          found_digest,
          dont_show_dialog_ident
        )
      else
        # Return the default value entered by user
        return SignatureCheckDialogs.GetDefaultDialogReturn(
          dont_show_dialog_ident,
          filename
        )
      end
    end

    # Callback handler function. Required callback prototype is <code>boolean(string filename, string name)</code>. The callback function should ask user whether the uknown digest can be accepted, returned true value means to accept the digest.
    # @return [Boolean]

    # zypp: askUserToAccepUnknownDigest
    def AcceptUnknownDigest(filename, digest)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      dont_show_dialog_ident = "-AcceptUnknownDigest-"

      # Show the popup?
      if SignatureCheckDialogs.GetShowThisPopup(
        dont_show_dialog_ident,
        filename
      )
        return SignatureCheckDialogs.UseFileWithUnknownDigest(
          filename,
          digest,
          dont_show_dialog_ident
        )
      else
        # Return the default value entered by user
        return SignatureCheckDialogs.GetDefaultDialogReturn(
          dont_show_dialog_ident,
          filename
        )
      end
    end

    # Name of the callback handler function. Required callback prototype is
    # boolean(string filename, string keyid, string keyname). The callback
    # function should ask user whether the unknown key can be accepted, returned
    # true value means to accept the file.
    #
    # zypp: askUserToAcceptUnknownKey
    #
    # (+DontShowAgain functionality) -- for one run in memory
    #
    # function for CallbackAcceptUnknownGpgKey()
    def AcceptUnknownGpgKey(filename, keyid, repoid)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      dont_show_dialog_ident = "-AcceptUnknownGpgKey-"

      # Show the popup?
      if SignatureCheckDialogs.GetShowThisPopup(
        dont_show_dialog_ident,
        filename
      )
        # Unknown keyname == "Unknown Key"
        return SignatureCheckDialogs.ItemSignedWithUnknownSignature(
          :file,
          filename,
          keyid,
          dont_show_dialog_ident,
          repoid
        )
        # Return the default value entered by user
      else
        return SignatureCheckDialogs.GetDefaultDialogReturn(
          dont_show_dialog_ident,
          filename
        )
      end
    end

    # Name of the callback handler function. Required callback prototype is
    # boolean(map<string,any> key). The callback
    # function should ask user whether the key is trusted, returned true value
    # means the key is trusted.
    #
    # zypp: askUserToImportKey
    #
    # function for CallbackImportGpgKey()
    def ImportGpgKey(key, repo_id)
      key = deep_copy(key)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      SignatureCheckDialogs.ImportGPGKeyIntoTrustedDialog(key, repo_id)
    end

    # Alternative implementation of #ImportGpgKey, used during installation,
    # that disables the repository if the key is not trusted and enables it
    # otherwise (a single call to Pkg.ServiceRefresh asks the user several
    # times for the same repository, last decision must prevail).
    #
    # zypp: askUserToImportKey
    #
    # function for CallbackImportGpgKey()
    def import_gpg_key_or_disable(key, repo_id)
      trusted = ImportGpgKey(key, repo_id)
      log.info "Setting enabled to #{trusted} for repo #{repo_id}, due to user reply to ImportGpgKey"
      Pkg.SourceSetEnabled(repo_id, trusted)
      trusted
    end

    # Name of the callback handler function. Required callback prototype is
    # boolean(string filename, map<string,any> key). The callback
    # function should ask user whether the unsigned file can be accepted,
    # returned true value means to accept the file.
    #
    # zypp: askUserToAcceptVerificationFailed
    #
    # function for CallbackAcceptVerificationFailed()
    def AcceptVerificationFailed(filename, key, repo_id)
      key = deep_copy(key)
      # Check signatures at all?
      if SignatureCheckDialogs.CheckSignaturesInYaST == false
        return @default_return_unchecked
      end

      SignatureCheckDialogs.UseCorruptedItem(:file, filename, key, repo_id)
    end

    # ============================ < Callbacks for Repositories > ============================

    # Name of the callback handler function. Required callback prototype is void
    # (string keyid, string keyname). The callback function should inform user
    # that a trusted key has been added.
    #
    # function for CallbackTrustedKeyAdded()
    def TrustedKeyAdded(key)
      key = deep_copy(key)
      Builtins.y2milestone(
        "Trusted key has been added: %1 / %2 (%3)",
        Ops.get_string(key, "id", ""),
        Ops.get_string(key, "fingerprint", ""),
        Ops.get_string(key, "name", "")
      )
      nil
    end

    # Name of the callback handler function. Required callback prototype is void
    # (string keyid, string keyname). The callback function should inform user
    # that a trusted key has been removed.
    #
    # function for CallbackTrustedKeyRemoved()
    def TrustedKeyRemoved(key)
      key = deep_copy(key)
      Builtins.y2milestone(
        "Trusted key has been removed: %1 / %2 (%3)",
        Ops.get_string(key, "id", ""),
        Ops.get_string(key, "fingerprint", ""),
        Ops.get_string(key, "name", "")
      )
      nil
    end

    publish function: :AcceptUnsignedFile, type: "boolean (string, integer)"
    publish function: :AcceptFileWithoutChecksum, type: "boolean (string)"
    publish function: :AcceptWrongDigest, type: "boolean (string, string, string)"
    publish function: :AcceptUnknownDigest, type: "boolean (string, string)"
    publish function: :AcceptUnknownGpgKey, type: "boolean (string, string, integer)"
    publish function: :ImportGpgKey, type: "boolean (map <string, any>, integer)"
    publish function: :import_gpg_key_or_disable, type: "boolean (map <string, any>, integer)"
    publish function: :AcceptVerificationFailed, type: "boolean (string, map <string, any>, integer)"
    publish function: :TrustedKeyAdded, type: "void (map <string, any>)"
    publish function: :TrustedKeyRemoved, type: "void (map <string, any>)"
  end

  SignatureCheckCallbacks = SignatureCheckCallbacksClass.new
  SignatureCheckCallbacks.main
end
