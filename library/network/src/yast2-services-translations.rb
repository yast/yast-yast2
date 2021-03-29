# typed: true
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
module Yast
  class Yast2ServicesTranslationsClient < Client
    def main
      # This file contains only translations for
      # FATE #300687: Ports for SuSEfirewall added via packages
      #
      # Translations are grabbed when 'make pot' is called.

      textdomain "firewall-services"

      @tmpstring = nil

      # TRANSLATORS: Name of Service (File name: avahi, RPM: avahi), can be used as check box, item in multiple selection box...
      @tmpstring = _("Zeroconf/Bonjour Multicast DNS")

      # TRANSLATORS: Description of a Service (File name: avahi, RPM: avahi), used as a common label or an item in table
      @tmpstring = _(
        "Zeroconf/Bonjour Multicast DNS (mDNS) ports for Service Discovery (DNS-SD)"
      )

      # TRANSLATORS: Name of Service (File name: cyrus-imapd, RPM: cyrus-imapd), can be used as check box, item in multiple selection box...
      @tmpstring = _("cyrus-imapd Server")

      # TRANSLATORS: Description of a Service (File name: cyrus-imapd, RPM: cyrus-imapd), used as a common label or an item in table
      @tmpstring = _("Open ports for the cyrus-imapd Server.")

      # TRANSLATORS: Name of Service (File name: dhcp-server, RPM: dhcp), can be used as check box, item in multiple selection box...
      @tmpstring = _("DHCPv4 Server")

      # TRANSLATORS: Description of a Service (File name: dhcp-server, RPM: dhcp), used as a common label or an item in table
      @tmpstring = _("Open ports for ISC DHCPv4 4.x server.")

      # TRANSLATORS: Name of Service (File name: dnsmasq-dhcp, RPM: dnsmasq), can be used as check box, item in multiple selection box...
      @tmpstring = _("dnsmasq")

      # TRANSLATORS: Description of a Service (File name: dnsmasq-dhcp, RPM: dnsmasq), used as a common label or an item in table
      @tmpstring = _("Open ports for the dnsmasq DNS/DHCP server.")

      # TRANSLATORS: Name of Service (File name: dnsmasq-dns, RPM: dnsmasq), can be used as check box, item in multiple selection box...
      @tmpstring = _("dnsmasq")

      # TRANSLATORS: Description of a Service (File name: dnsmasq-dns, RPM: dnsmasq), used as a common label or an item in table
      @tmpstring = _("Open ports for the dnsmasq DNS/DHCP server.")

      # TRANSLATORS: Name of Service (File name: hplip, RPM: hplip), can be used as check box, item in multiple selection box...
      @tmpstring = _("mDNS/Bonjour support for HPLIP")

      # TRANSLATORS: Description of a Service (File name: hplip, RPM: hplip), used as a common label or an item in table
      @tmpstring = _(
        "Firewall Configuration file for mDNS/Bonjour support for HPLIP"
      )

      # TRANSLATORS: Name of Service (File name: iceccd, RPM: icecream), can be used as check box, item in multiple selection box...
      @tmpstring = _("icecream daemon")

      # TRANSLATORS: Description of a Service (File name: iceccd, RPM: icecream), used as a common label or an item in table
      @tmpstring = _("opens socket for the icecream compilation daemon")

      # TRANSLATORS: Name of Service (File name: icecream-scheduler, RPM: icecream), can be used as check box, item in multiple selection box...
      @tmpstring = _("icecream scheduler")

      # TRANSLATORS: Description of a Service (File name: icecream-scheduler, RPM: icecream), used as a common label or an item in table
      @tmpstring = _("Opens ports for the icecream scheduler")

      # TRANSLATORS: Name of Service (File name: isns, RPM: isns), can be used as check box, item in multiple selection box...
      @tmpstring = _("iSNS Daemon")

      # TRANSLATORS: Description of a Service (File name: isns, RPM: isns), used as a common label or an item in table
      @tmpstring = _("Open ports for iSNS daemon with broadcast allowed.")

      # TRANSLATORS: Name of Service (File name: netbios-server, RPM: samba), can be used as check box, item in multiple selection box...
      @tmpstring = _("Netbios Server")

      # TRANSLATORS: Description of a Service (File name: netbios-server, RPM: samba), used as a common label or an item in table
      @tmpstring = _(
        "Open ports for Samba Netbios server with broadcast allowed."
      )

      # TRANSLATORS: Name of Service (File name: nfs-client, RPM: nfs-client), can be used as check box, item in multiple selection box...
      @tmpstring = _("NFS Client")

      # TRANSLATORS: Description of a Service (File name: nfs-client, RPM: nfs-client), used as a common label or an item in table
      @tmpstring = _(
        "Firewall configuration for NFS client. Open ports for NFS client to allow connection to an NFS server."
      )

      # TRANSLATORS: Name of Service (File name: nfs-kernel-server, RPM: nfs-kernel-server), can be used as check box, item in multiple selection box...
      @tmpstring = _("NFS Server Service")

      # TRANSLATORS: Description of a Service (File name: nfs-kernel-server, RPM: nfs-kernel-server), used as a common label or an item in table
      @tmpstring = _(
        "Firewall configuration for NFS kernel server. Open ports for NFS to allow other hosts to connect."
      )

      # TRANSLATORS: Name of Service (File name: ntp, RPM: ntp), can be used as check box, item in multiple selection box...
      @tmpstring = _("xntp Server")

      # TRANSLATORS: Description of a Service (File name: ntp, RPM: ntp), used as a common label or an item in table
      @tmpstring = _("Open ports for xntp.")

      # TRANSLATORS: Name of Service (File name: openldap, RPM: openldap2), can be used as check box, item in multiple selection box...
      @tmpstring = _("OpenLDAP Server")

      # TRANSLATORS: Description of a Service (File name: openldap, RPM: openldap2), used as a common label or an item in table
      @tmpstring = _("Open ports for the OpenLDAP server (slapd).")

      # TRANSLATORS: Name of Service (File name: openslp, RPM: openslp-server), can be used as check box, item in multiple selection box...
      @tmpstring = _("OpenSLP Server (SLP)")

      # TRANSLATORS: Description of a Service (File name: openslp, RPM: openslp-server), used as a common label or an item in table
      @tmpstring = _("Enable OpenSLP server to advertise services.")

      # TRANSLATORS: Name of Service (File name: rsync-server, RPM: rsync), can be used as check box, item in multiple selection box...
      @tmpstring = _("Rsync server")

      # TRANSLATORS: Description of a Service (File name: rsync-server, RPM: rsync), used as a common label or an item in table
      @tmpstring = _(
        "Opens port for rsync server in order to allow remote synchronization"
      )

      # TRANSLATORS: Name of Service (File name: samba-client, RPM: samba-client), can be used as check box, item in multiple selection box...
      @tmpstring = _("Samba Client")

      # TRANSLATORS: Description of a Service (File name: samba-client, RPM: samba-client), used as a common label or an item in table
      @tmpstring = _("Enable browsing of SMB shares.")

      # TRANSLATORS: Name of Service (File name: samba-server, RPM: samba), can be used as check box, item in multiple selection box...
      @tmpstring = _("Samba Server")

      # TRANSLATORS: Description of a Service (File name: samba-server, RPM: samba), used as a common label or an item in table
      @tmpstring = _("Open ports for Samba server.")

      # TRANSLATORS: Name of Service (File name: sendmail, RPM: sendmail), can be used as check box, item in multiple selection box...
      @tmpstring = _("SMTP with sendmail")

      # TRANSLATORS: Description of a Service (File name: sendmail, RPM: sendmail), used as a common label or an item in table
      @tmpstring = _("Firewall configuration file for sendmail")

      # TRANSLATORS: Name of Service (File name: sshd, RPM: openssh), can be used as check box, item in multiple selection box...
      @tmpstring = _("Secure Shell Server")

      # TRANSLATORS: Description of a Service (File name: sshd, RPM: openssh), used as a common label or an item in table
      @tmpstring = _("Open ports for the Secure Shell server.")

      # TRANSLATORS: Name of Service (File name: svnserve, RPM: subversion), can be used as check box, item in multiple selection box...
      @tmpstring = _("svnserve")

      # TRANSLATORS: Description of a Service (File name: svnserve, RPM: subversion), used as a common label or an item in table
      @tmpstring = _("Open ports for svnserve")

      # TRANSLATORS: Name of Service (File name: vnc-httpd, RPM: tightvnc), can be used as check box, item in multiple selection box...
      @tmpstring = _("VNC mini-HTTP server")

      # TRANSLATORS: Description of a Service (File name: vnc-httpd, RPM: tightvnc), used as a common label or an item in table
      @tmpstring = _("Opens the VNC HTTP ports so that browsers can connect.")

      # TRANSLATORS: Name of Service (File name: vnc-server, RPM: tightvnc), can be used as check box, item in multiple selection box...
      @tmpstring = _("VNC")

      # TRANSLATORS: Description of a Service (File name: vnc-server, RPM: tightvnc), used as a common label or an item in table
      @tmpstring = _("Open VNC server ports so that viewers can connect.")

      # TRANSLATORS: Name of Service (File name: vsftpd, RPM: vsftpd), can be used as check box, item in multiple selection box...
      @tmpstring = _("vsftpd Server")

      # TRANSLATORS: Description of a Service (File name: vsftpd, RPM: vsftpd), used as a common label or an item in table
      @tmpstring = _("Open ports for vsftpd server.")

      # TRANSLATORS: Name of Service (File name: ypbind, RPM: ypbind), can be used as check box, item in multiple selection box...
      @tmpstring = _("NIS Client")

      # TRANSLATORS: Description of a Service (File name: ypbind, RPM: ypbind), used as a common label or an item in table
      @tmpstring = _("The ypbind daemon binds NIS clients to an NIS domain.")

      nil
    end
  end
end

Yast::Yast2ServicesTranslationsClient.new.main
