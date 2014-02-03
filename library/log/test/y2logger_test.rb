#!/usr/bin/env rspec

require_relative "../src/lib/log/y2logger.rb"

module Yast
  describe Y2Logger do

    TEST_MESSAGE = "Testing"

    before do
      @test_logger = Y2Logger.instance
    end

    it "logs debug messages via y2debug()" do
      Yast.should_receive(:y2debug).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.debug TEST_MESSAGE
    end

    it "logs info messages via y2milestone()" do
      Yast.should_receive(:y2milestone).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.info TEST_MESSAGE
    end

    it "logs warnings via y2warning()" do
      Yast.should_receive(:y2warning).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.warn TEST_MESSAGE
    end

    it "logs errors via y2error()" do
      Yast.should_receive(:y2error).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.error TEST_MESSAGE
    end

    it "logs fatal errors via y2error()" do
      Yast.should_receive(:y2error).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.fatal TEST_MESSAGE
    end

    it "handles a message passed via block" do
      Yast.should_receive(:y2milestone).with(Y2Logger::CALL_FRAME, TEST_MESSAGE)
      @test_logger.info { TEST_MESSAGE }
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
