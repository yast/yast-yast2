# Copyright (c) [2021] SUSE LLC
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
require "y2issues"

Yast.import "Report"

module Y2Issues
  # This class provides a mechanism to report YaST2 issues
  #
  # In order to integrate nicely with AutoYaST, it honors the Yast::Report
  # settings.
  class Reporter
    include Yast::I18n
    include Yast::Logger

    # @param issues          [List] Issues list
    # @param report_settings [Hash] Report settings (see Report.Export)
    def initialize(issues, report_settings: Yast::Report.Export)
      textdomain "base"
      @presenter = Presenter.new(issues)
      @level = issues.error? ? :error : :warn
      @log, @show, @timeout = find_settings(report_settings, @level)
    end

    # Reports the issues to the user
    #
    # Depending on the given report settings, it may display a pop-up, and/or log the error.
    #
    # @return [Symbol, nil] response of the user to the pop-up, nil if no pop-up was displayed
    def report
      log_issues if @log
      show_issues if @show
    end

  private

    attr_reader :level, :presenter

    # Displays a pop-up containing the issues
    def show_issues
      head = (level == :error) ? :error : :warning
      Yast2::Popup.show(
        presenter.to_html, richtext: true, headline: head, buttons: :ok, timeout: @timeout
      )
    end

    # Writes the issues
    def log_issues
      log.send(level, presenter.to_plain)
    end

    # Reads reporting settings depending on the error level
    #
    # @param settings [Hash] Reporting settings (as exported by Report.Export)
    # @param level [Symbol] :error or :warn
    def find_settings(settings, level)
      key = (level == :error) ? "errors" : "warnings"
      hash = settings[key]
      [hash["log"], hash["show"], hash["timeout"]]
    end
  end
end
