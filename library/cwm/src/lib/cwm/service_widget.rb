# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "yast2/service_widget"
require "cwm/custom_widget"

module CWM
  # CWM wrapper for Yast2::ServiceWidget
  class ServiceWidget < CustomWidget
    # creates new widget instance for given service
    # @param service [Yast2::SystemService,Yast2::CompoundService] service to be configured
    def initialize(service)
      @service_widget = Yast2::ServiceWidget.new(service)
      self.handle_all_events = true
    end

    def contents
      @service_widget.content
    end

    def handle(event)
      log.info "handling event #{event.inspect}"
      return unless event

      @service_widget.handle_input(event["ID"])
    end

    def store
      @service_widget.store
    end
  end
end
