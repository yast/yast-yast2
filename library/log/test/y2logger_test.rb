#!/usr/bin/env rspec

require_relative "../src/lib/log/y2logger.rb"

# for logging into a string instead of a file
require "stringio"
# gethostname
require "socket"

module Yast
  describe Y2Logger do
    before do
      # log into a string to easily test the result
      @log = StringIO.new
      @test_logger = Y2Logger.new(@log)
    end

    it "logs the passed message" do
      @test_logger.info "@@@ Testing @@@"
      expect(log).to match "@@@ Testing @@@"
    end

    it "logs with [Ruby] component" do
      @test_logger.info "Testing"
      expect(log).to match "[Ruby]"
    end

    it "logs info messages with '<1>' level" do
      @test_logger.info "Testing"
      expect(log).to match "<1>"
    end

    it "logs warnings with '<2>' level" do
      @test_logger.warn "Testing"
      expect(log).to match "<2>"
    end

    it "logs errors with '<3>' level" do
      @test_logger.error "Testing"
      expect(log).to match "<3>"
    end

    it "logs fatal errors with '<3>' level" do
      @test_logger.fatal "Testing"
      expect(log).to match "<3>"
    end

    it "logs the hostname" do
      @test_logger.info "Testing"
      expect(log).to match Socket.gethostname
    end

    it "logs the process ID (PID)" do
      @test_logger.info "Testing"
      expect(log).to match "(#{Process.pid})"
    end

    it "logs the file location into the log" do
      @test_logger.info "Testing"
      expect(log).to match "#{__FILE__}:#{__LINE__ - 1}"
    end

    it "logs in y2log compatible format" do
      @test_logger.info "Testing"
      expect(log).to match /\A\d+-\d+-\d+ \d+:\d+:\d+ <1> #{Socket.gethostname}\(#{Process.pid}\) \[Ruby\] #{__FILE__}:\d+ Testing$/
    end

    context "when Y2DEBUG is not set" do
      before do
        ENV.stub(:[]).with("Y2DEBUG").and_return(nil)
        @test_logger = Y2Logger.new(@log)
      end

      it "does not log debug messages" do
        @test_logger.debug "Testing"
        expect(log).to eq ""
      end

      it "logs info messages with '<1>' level" do
        @test_logger.info "Testing"
        expect(log).to match "<1>"
      end
    end

    context "when Y2DEBUG is set" do
      before do
        ENV.stub(:[]).with("Y2DEBUG").and_return("1")
        @test_logger = Y2Logger.new(@log)
      end

      it "logs debug messages with '<0>' level" do
        @test_logger.debug "Testing"
        expect(log).to match "<0>"
      end

      it "logs info messages with '<1>' level" do
        @test_logger.info "Testing"
        expect(log).to match "<1>"
      end
    end

    # helper method to read the logged value
    def log
      # read the created log from string
      @log.rewind
      @log.read
    end
  end

  describe YastLogger do
    it "returns a Logger class instance" do
      expect(YastLogger.instance.log).to be_kind_of(::Logger)
    end
  end

  describe Yast::Logger do
    it "module adds log() method for accessing the Logger" do
      class Test
        include Yast::Logger
      end
      expect(Test.log).to be_kind_of(::Logger)
      expect(Test.new.log).to be_kind_of(::Logger)
    end
  end

end
