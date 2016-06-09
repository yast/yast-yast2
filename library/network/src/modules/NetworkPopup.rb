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
# File:
#   NetworkPopup.ycp
#
# Summary:
#   Popup dialogs for browsing the local network
#
# Authors:
#	Martin Vidner <mvidner@suse.cz>
#	Ladislav Slezak <lslezak@suse.cz>
#
# $Id$
#
# Network browsing dialogs - all hosts, NFS servers, exports of the NFS server
#
require "yast"

module Yast
  class NetworkPopupClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Label"
      Yast.import "NetworkInterfaces"

      # cache all found hosts on the local network
      @found_hosts = nil

      # cache all found NFS servers on the local network
      @found_nfs_servers = nil
    end

    # Let the user choose one of a list of items
    # @param [String] title	selectionbox title
    # @param [Array<String>] items	a list of items
    # @param [String] selected	preselected a value in the list
    # @return		one item or nil
    def ChooseItem(_title, items, selected)
      items = deep_copy(items)
      item = nil

      items = Builtins.maplist(items) do |i|
        device_name = NetworkInterfaces.GetValue(i, "NAME")
        if device_name.nil? || device_name == ""
          # TRANSLATORS: Informs that device name is not known
          device_name = _("Unknown device")
        end
        if Ops.greater_than(Builtins.size(device_name), 30)
          device_name = Ops.add(Builtins.substring(device_name, 0, 27), "...")
        end
        ip_addr = if NetworkInterfaces.GetValue(i, "BOOTPROTO") == "dhcp"
                    # TRANSLATORS: Informs that the IP address is assigned via DHCP
                    _("DHCP address")
                  else
                    NetworkInterfaces.GetValue(i, "IPADDR")
                  end
        if ip_addr.nil? || ip_addr == ""
          # TRANSLATORS: table item, informing that device has no IP address
          ip_addr = _("No IP address assigned")
        end
        conn = _("No")
        conn = _("Yes") if NetworkInterfaces.IsConnected(i)
        Item(
          Id(i),
          NetworkInterfaces.GetDeviceTypeName(i),
          device_name,
          ip_addr,
          i,
          conn
        )
      end

      UI.OpenDialog(
        VBox(
          HSpacing(60),
          HBox(
            # translators: table header - details about the network device
            Table(
              Id(:items),
              Header(
                _("Device Type"),
                _("Device Name"),
                _("IP Address"),
                _("Device ID"),
                _("Connected")
              ),
              items
            ),
            VSpacing(10)
          ),
          ButtonBox(
            PushButton(
              Id(:ok),
              Opt(:default, :key_F10, :okButton),
              Label.OKButton
            ),
            PushButton(
              Id(:cancel),
              Opt(:key_F9, :cancelButton),
              Label.CancelButton
            )
          )
        )
      )
      UI.ChangeWidget(Id(:items), :CurrentItem, selected)
      UI.SetFocus(Id(:items))
      ret = nil
      ret = UI.UserInput while ret != :cancel && ret != :ok

      if ret == :ok
        item = Convert.to_string(UI.QueryWidget(Id(:items), :CurrentItem))
      end
      UI.CloseDialog

      item
    end

    # Let the user choose one of a list of items
    # @param [String] title	selectionbox title
    # @param [Array<String>] items	a list of items
    # @param [String] selected	preselected a value in the list
    # @return		one item or nil
    def ChooseItemSimple(title, items, selected)
      items = deep_copy(items)
      item = nil

      items = Builtins.maplist(items) { |i| Item(Id(i), i, i == selected) }

      UI.OpenDialog(
        VBox(
          HSpacing(40),
          HBox(SelectionBox(Id(:items), title, items), VSpacing(10)),
          ButtonBox(
            PushButton(
              Id(:ok),
              Opt(:default, :key_F10, :okButton),
              Label.OKButton
            ),
            PushButton(
              Id(:cancel),
              Opt(:key_F9, :cancelButton),
              Label.CancelButton
            )
          )
        )
      )
      UI.SetFocus(Id(:items))
      ret = nil
      ret = UI.UserInput while ret != :cancel && ret != :ok

      if ret == :ok
        item = Convert.to_string(UI.QueryWidget(Id(:items), :CurrentItem))
      end
      UI.CloseDialog

      item
    end

    # Give me NFS server name on the local network
    #
    # display dialog with all local NFS servers
    # @param [String] selected	preselected a value in the list
    # @return		a hostname or nil if "Cancel" was pressed
    def NFSServer(selected)
      if @found_nfs_servers.nil?
        # label message
        UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
        # #71064
        # this works also if ICMP broadcasts are ignored
        cmd = "/usr/sbin/rpcinfo -b mountd 1 | cut -d ' ' -f 2 | sort -u"
        out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        @found_nfs_servers = Builtins.filter(
          Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
        ) { |s| s != "" }
        UI.CloseDialog

        @found_nfs_servers = if @found_nfs_servers.nil?
          []
        else
          # sort list of servers
          Builtins.sort(@found_nfs_servers)
        end
      end

      # selection box label
      ret = ChooseItemSimple(_("&NFS Servers"), @found_nfs_servers, selected)
      ret
    end

    # Give me one host name on the local network
    #
    # display dialog with all hosts on the local network
    # @param [String] selected	preselect a value in the list
    # @return		a hostname or nil if "Cancel" was pressed
    def HostName(selected)
      if @found_hosts.nil?
        # label message
        UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
        @found_hosts = Convert.convert(
          Builtins.sort(Convert.to_list(SCR.Read(path(".net.hostnames")))),
          from: "list",
          to:   "list <string>"
        )
        UI.CloseDialog

        @found_hosts = [] if @found_hosts.nil?
      end

      # selection box label
      ret = ChooseItemSimple(_("Re&mote Hosts"), @found_hosts, selected)
      ret
    end

    # Give me export path of selected server
    #
    # display dialog with all exported directories from the selected server
    # @param [String] server	a NFS server name
    # @param [String] selected	preselected a value in the list
    # @return		an export or nil if "Cancel" was pressed
    def NFSExport(server, selected)
      dirs = Convert.convert(
        SCR.Read(path(".net.showexports"), server),
        from: "any",
        to:   "list <string>"
      )

      dirs = [] if dirs.nil?

      # selection box label
      ret = ChooseItemSimple(_("&Exported Directories"), dirs, selected)
      ret
    end

    publish function: :ChooseItem, type: "string (string, list <string>, string)"
    publish function: :NFSServer, type: "string (string)"
    publish function: :HostName, type: "string (string)"
    publish function: :NFSExport, type: "string (string, string)"
  end

  NetworkPopup = NetworkPopupClass.new
  NetworkPopup.main
end
