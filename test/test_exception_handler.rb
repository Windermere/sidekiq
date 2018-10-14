# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq2/exception_handler'
require 'stringio'
require 'logger'

ExceptionHandlerTestException = Class.new(StandardError)
TEST_EXCEPTION = ExceptionHandlerTestException.new("Something didn't work!")

class Component
  include Sidekiq2::ExceptionHandler

  def invoke_exception(args)
    raise TEST_EXCEPTION
  rescue ExceptionHandlerTestException => e
    handle_exception(e,args)
  end
end

class TestExceptionHandler < Sidekiq2::Test
  describe "with mock logger" do
    before do
      @old_logger = Sidekiq2.logger
      @str_logger = StringIO.new
      Sidekiq2.logger = Logger.new(@str_logger)
    end

    after do
      Sidekiq2.logger = @old_logger
    end

    it "logs the exception to Sidekiq2.logger" do
      Component.new.invoke_exception(:a => 1)
      @str_logger.rewind
      log = @str_logger.readlines
      assert_match(/"a":1/, log[0], "didn't include the context")
      assert_match(/Something didn't work!/, log[1], "didn't include the exception message")
      assert_match(/test\/test_exception_handler.rb/, log[2], "didn't include the backtrace")
    end

    describe "when the exception does not have a backtrace" do
      it "does not fail" do
        exception = ExceptionHandlerTestException.new
        assert_nil exception.backtrace

        begin
          Component.new.handle_exception exception
          pass
        rescue StandardError
          flunk "failed handling a nil backtrace"
        end
      end
    end
  end

end
