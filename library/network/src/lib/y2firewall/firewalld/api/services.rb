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
      # This module contains specific API methods for handling services
      # definition and configuration.
      module Services
        # Creates a new service definition for the given service name
        #
        # @param service [String] The firewall service
        # @return [Boolean] true if the new service was created
        def create_service(service)
          modify_command("--new-service=#{service}", permanent: !offline?)
        end

        # Remove the service definition for the given service name
        #
        # @param service [String] The firewall service
        # @return [Boolean] true if the service was deleted
        def delete_service(service)
          modify_command("--delete-service=#{service}", permanent: !offline?)
        end

        # Return the list of availale firewalld services
        #
        # @return [Array<String>] List of firewall services
        def services
          string_command("--get-services").split(" ")
        end

        # Show all the service declaration (name, description, ports,
        # protocols and modules)
        #
        # @param service [String] The firewall service name
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [Array<String>] list of all information for the given service
        def info_service(service, permanent: permanent?)
          string_command("--info-service=#{service}", "--verbose", permanent: permanent).split("\n")
        end

        # Full name or short description of the service
        #
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [String] Short description for service
        def service_short(service, permanent: permanent?)
          # these may not exist on early firewalld releases
          string_command("--service=#{service}", "--get-short", permanent: permanent)
        end

        # Modify the full name or short description of the service
        #
        # @param service [String] The firewall service
        # @param short_description [String] the new service name or description
        def modify_service_short(service, short_description)
          modify_command("--service=#{service}", "--set-short=#{short_description}",
            permanent: !offline?)
        end

        # @param service [String] the firewall service
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [String] Description for service
        def service_description(service, permanent: permanent?)
          string_command("--service=#{service}", "--get-description", permanent: permanent)
        end

        # Modify the long description of the service
        #
        # @param service [String] The firewall service
        # @param long_description [String] the new service description
        def modify_service_description(service, long_description)
          modify_command("--service=#{service}", "--set-description=#{long_description}",
            permanent: !offline?)
        end

        # Returns whether the service definition for the service name given is
        # present or not.
        #
        # @param service [String] The firewall service
        # @return [Boolean] True if service definition exists
        def service_supported?(service)
          services.include?(service)
        end

        # Return the list of ports allowed by the given service
        #
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [Array<String>] The firewall service ports
        def service_ports(service, permanent: permanent?)
          string_command("--service=#{service}", "--get-ports", permanent: permanent).split(" ")
        end

        # @param service [String] The firewall service
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [Array<String>] The firewall service protocols
        def service_protocols(service, permanent: permanent?)
          string_command("--service=#{service}", "--get-protocols", permanent: permanent).split(" ")
        end

        # @param service [String] The firewall service
        # @param permanent [Boolean] if true and firewalld is running it
        #   reads the permanent configuration
        # @return [Array<String>] The firewall service modules
        def service_modules(service, permanent: permanent?)
          string_command("--service=#{service}", "--get-modules", permanent: permanent).split(" ")
        end

        # @param service [String] The firewall service
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true and firewalld is running it
        #   modifies the permanent configuration
        # @return [Boolean] True if port was removed from service
        def remove_service_port(service, port, permanent: permanent?)
          modify_command("--service=#{service}", "--remove-port=#{port}", permanent: permanent)
        end

        # @param service [String] The firewall firewall
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true and firewalld is running it
        #   modifies the permanent configuration
        # @return [Boolean] True if port was removed from service
        def add_service_port(service, port, permanent: permanent?)
          modify_command("--service=#{service}", "--add-port=#{port}", permanent: permanent)
        end
      end
    end
  end
end
