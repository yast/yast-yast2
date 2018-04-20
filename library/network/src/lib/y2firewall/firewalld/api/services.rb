# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2018 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

module Y2Firewall
  class Firewalld
    class Api
      # This module contains specific api methods for handling services
      # definition and configuration.
      module Services
        # @param service [String] The firewall service
        def new_service(service)
          query_command("--new-service=#{service}", permanent: true)
        end

        # @return [Array<String>] List of firewall services
        def services
          string_command("--get-services").split(" ")
        end

        # @param service [String] The firewall service
        # @return [Array<String>] list of all information for the given service
        def info_service(service)
          string_command("--info-service", service.to_s, permanent: true).split("\n")
        end

        # @param service [String] The firewall service
        # @return [String] Short description for service
        def service_short(service)
          # these may not exist on early firewalld releases
          string_command("--service=#{service}", "--get-short", permanent: true)
        end

        # @param service [String] the firewall service
        # @return [String] Description for service
        def service_description(service)
          string_command("--service=#{service}", "--get-description", permanent: true)
        end

        # @param service [String] The firewall service
        # @return [Boolean] True if service definition exists
        def service_supported?(service)
          services.include?(service)
        end

        # @param service [String] The firewall service
        # @return [Array<String>] The firewall service ports
        def service_ports(service)
          string_command("--service=#{service}", "--get-ports", permanent: true).split(" ")
        end

        # @param service [String] The firewall service
        # @return [Array<String>] The firewall service protocols
        def service_protocols(service)
          string_command("--service=#{service}", "--get-protocols", permanent: true).split(" ")
        end

        # @param service [String] The firewall service
        # @return [Array<String>] The firewall service modules
        def service_modules(service)
          string_command("--service=#{service}", "--get-modules", permanent: true).split(" ")
        end

        # @param service [String] The firewall service
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if port was removed from service
        def remove_service_port(service, port, permanent: permanent?)
          string_command("--service=#{service}", "--remove-port=#{port}", permanent: permanent)
        end

        # @param service [String] The firewall firewall
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if port was removed from service
        def add_service_port(service, port, permanent: permanent?)
          string_command("--service=#{service}", "--add-port=#{port}", permanent: permanent)
        end
      end
    end
  end
end
