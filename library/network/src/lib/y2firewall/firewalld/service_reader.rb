# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "English"
require "yast"
require "y2firewall/firewalld/api"
require "y2firewall/firewalld/service"

module Y2Firewall
  class Firewalld
    # Class to help parsing firewall-cmd --info-service=service output
    class ServiceReader
      include Yast::Logger

      # @return [Array<Y2Firewall::Firewalld::Service>]
      def read(name)
        info = Y2Firewall::Firewalld.instance.api.info_service(name)
        raise(Service::NotFound, name) if $CHILD_STATUS.exitstatus == 101
        service = Service.new(name: name)

        info.each do |line|
          next if line.lstrip.empty?
          next if line.start_with?(/#{name}/)

          attribute, value = line.split(":\s")
          attribute = attribute.lstrip.tr("-", "_")
          attribute = "short" if attribute == "summary"
          next unless service.respond_to?("#{attribute}=")
          if service.attributes.include?(attribute.to_sym)
            service.public_send("#{attribute}=", value.to_s)
          else
            service.public_send("#{attribute}=", value.to_s.split)
          end
        end

        service.untouched!
        service
      end
    end
  end
end
