# Copyright (c) [2019] SUSE LLC
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2network/hostname"

Yast.import "IP"
Yast.import "Mode"
Yast.import "Hostname"
Yast.import "String"

module Y2Network
  module ConfigReader
    # This class is reponsible of reading the current Hostname or the one
    # proposed / configured through linuxrc in case of an installation.
    class Hostname
      include Yast::Logger

      def self.from_system
        # In installation (standard, or AutoYaST one), prefer /etc/install.inf
        # (because HOSTNAME comes with netcfg.rpm already, #144687)
        if (Yast::Mode.installation || Yast::Mode.autoinst) && File.exist?("/etc/install.inf")
          fqhostname = read_hostname_from_install_inf
        end

        # reads setup from /etc/HOSTNAME, returns a default if nothing found
        fqhostname = Yast::Hostname.CurrentFQ if fqhostname.nil? || fqhostname.empty?

        Y2Network::Hostname.new(fqdn: fqhostname)
      end

    private

      def read_hostname_from_install_inf
        install_inf_hostname = Yast::SCR.Read(path(".etc.install_inf.Hostname")) || ""
        log.info("Got #{install_inf_hostname} from install.inf")

        return "" if install_inf_hostname.empty?

        # if the name is actually IP, try to resolve it (bnc#556613, bnc#435649)
        if Yast::IP.Check(install_inf_hostname)
          fqhostname = hosts_hostname_for(install_inf_hostname)
          log.info("Got #{fqhostname} after resolving IP from install.inf")
        else
          fqhostname = install_inf_hostname
        end

        fqhostname
      end

      # Get the canonical hostname from hosts for a given IP address
      #
      # @param [String] ip given IP address
      # @return resolved canonical hostname (FQDN) for given IP or empty string in case of failure.
      def hosts_hostname_for(ip)
        getent = Yast::SCR.Execute(path(".target.bash_output"), "/usr/bin/getent hosts #{ip.shellescape}")
        exit_code = getent.fetch("exit", -1)

        if exit_code != 0
          log.error("ResolveIP: getent call failed (#{getent})")

          return ""
        end

        hostname_from_getent(getent.fetch("stdout", ""))
      end

      # Handles input as one line of getent output. Returns first hostname found
      # on the line (= canonical hostname).
      #
      # @param [String] line in /etc/hosts format
      # @return canonical hostname from given line
      def hostname_from_getent(line)
        #  line is expected same format as is used in /etc/hosts without additional
        #  comments (getent removes comments from the end).
        #
        #  /etc/hosts line is formatted this way (man 5 hosts):
        #
        #      <ip address> <canonical hostname> [<alias> ...]
        #
        #  - field separators are at least one space and/or tab.
        #  - <canonical hostname>, in generic it is "a computer's unique name". In case
        #  of DNS world, <canonical hostname> is FQDN ("A" record), then <hostname> is
        #  <canonical hostname> without domain part. For example:
        #
        #      foo.example.com. IN A 1.2.3.4
        #
        #  <canonical hostname> => foo.example.com
        #  <hostname> => foo
        #
        canonical_hostname = Yast::Builtins.regexpsub(
          line,
          Yast::Builtins.sformat("^[%1]+[[:blank:]]+(.*)", Yast::IP.ValidChars),
          "\\1"
        )

        canonical_hostname = Yast::String.FirstChunk(canonical_hostname, " \t\n")
        canonical_hostname = Yast::String.CutBlanks(canonical_hostname)

        if !Yast::Hostname.CheckDomain(canonical_hostname) &&
            !Yast::Hostname.Check(canonical_hostname)
          log.error("GetHostnameFromGetent: Invalid hostname detected (#{canonical_hostname})")
          log.error("GetHostnameFromGetent: input params - begin")
          log.error(line)
          log.error("GetHostnameFromGetent: input params - end")

          return ""
        end

        log.info("GetHostnameFromGetEnt: canonical hostname => (#{canonical_hostname})")

        canonical_hostname
      end
    end
  end
end
