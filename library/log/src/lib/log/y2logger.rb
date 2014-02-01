# encoding: utf-8

require 'logger'
require 'singleton'
require 'socket'

module Yast

  # A Ruby Logger which logs in usual Yast y2log formatting
  class Y2Logger < ::Logger

    SEVERITY_MAPPING = {
      DEBUG => 0,
      INFO => 1,
      WARN => 2,
      ERROR => 3,
      FATAL => 3,
      UNKNOWN => 5
    }

    # redefine the format to the y2log format
    def format_message(severity, timestamp, progname, msg)
      # remove the function name from the caller location
      location = caller(3).first.gsub(/:in `.*'$/, "")
      "#{timestamp.strftime(datetime_format)} #{severity} #{Socket.gethostname}(#{Process.pid}) #{progname} #{location} #{msg}\n"
    end

    def initialize(*args)
      super
      self.datetime_format = "%Y-%m-%d %H:%M:%S"
      self.progname = "[Ruby]"
      # TODO: it does not support changing the level at runtime,
      # e.g. via Shift-F7 magic key
      self.level = ENV["Y2DEBUG"] == "1" ? ::Logger::DEBUG : ::Logger::INFO
    end

    private

    # redefine severity formatting
    def format_severity(severity)
      "<#{SEVERITY_MAPPING[severity] || 5}>"
    end
  end

  # Provides the global shared Y2logger instance writing to /var/log/YaST2/y2log
  # (or ~/.y2log if the file is not writable).
  #
  # It can be used for logging external Ruby code into y2log
  #
  # @example Allow external code to log into y2log
  #   # this depends on the target library, see it's documentation how to set the logger
  #   FooBar::Logger.instance.log = YastLogger.instance.log
  #   Baz.set_logger(YastLogger.instance.log)
  class YastLogger
    include Singleton

    Y2LOGFILE = "/var/log/YaST2/y2log"

    attr_accessor :log

    def initialize
      # Yast compatibility - log to home if not running as root
      # (of if the file is not writable)
      if File.exist?(Y2LOGFILE)
        log_file = File.writable?(Y2LOGFILE) ? Y2LOGFILE :  "#{ENV['HOME']}/.y2log"
      else
        log_file = File.writable?(File.dirname(Y2LOGFILE)) ? Y2LOGFILE : "#{ENV['HOME']}/.y2log"
      end

      # when creating the log file make sure it is readable only by the user
      # (it might contain sensitive data like passwords, registration code, etc.)
      File.write(log_file, "", { :perm => 0600 }) unless File.exist?(log_file)

      @log = Yast::Y2Logger.new(log_file)
    end
  end

  # This module provides access to Yast specific logging
  #
  # @example Use YastLogger in an easy way
  #   require "log/y2logger"
  #   class Foo
  #     include Yast::Logger
  #
  #     def foo
  #       # this will be logged into y2log using the usual y2log format
  #       log.debug "debug"
  #       log.error "error"
  #     end
  #   end
  module Logger
    def log
      YastLogger.instance.log
    end

    def self.included(base)
      base.extend self
    end
  end

end
