# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq1/logging'

class TestLogging < Sidekiq1::Test
  describe Sidekiq1::Logging do
    describe "#with_context" do
      def ctx
        Sidekiq1::Logging.logger.formatter.context
      end

      it "has no context by default" do
        assert_nil ctx
      end

      it "can add a context" do
        Sidekiq1::Logging.with_context "xx" do
          assert_equal " xx", ctx
        end
        assert_nil ctx
      end

      it "can use multiple contexts" do
        Sidekiq1::Logging.with_context "xx" do
          assert_equal " xx", ctx
          Sidekiq1::Logging.with_context "yy" do
            assert_equal " xx yy", ctx
          end
          assert_equal " xx", ctx
        end
        assert_nil ctx
      end
    end
  end
end
