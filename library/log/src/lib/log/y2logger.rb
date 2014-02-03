# encoding: utf-8

require "logger"
require "singleton"

require "yast"

module Yast

  # A Ruby Logger which wraps Yast.y2*() calls
  class Y2Logger < ::Logger
    include Singleton

    # location of the caller
    CALL_FRAME = 2

    def add(severity, progname = nil, message = nil, &block)
      message = yield if block_given?

      case severity
      when DEBUG
        Yast.y2debug(CALL_FRAME, message)
      when INFO
        Yast.y2milestone(CALL_FRAME, message)
      when WARN
        Yast.y2warning(CALL_FRAME, message)
      when ERROR
        Yast.y2error(CALL_FRAME, message)
      when FATAL
        Yast.y2error(CALL_FRAME, message)
      when UNKNOWN
        Yast.y2internal(CALL_FRAME, message)
      else
        Yast.y2internal(CALL_FRAME, "Unknown error level #{severity}: Error: #{message}")
      end
    end

    def initialize(*args)
      # do not write to any file, the actual logging is implemented in add()
      super(nil)
      # process also debug messages but might not be logged in the end
      self.level = ::Logger::DEBUG
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
      Y2Logger.instance
    end

    def self.included(base)
      base.extend self
    end
  end

end
