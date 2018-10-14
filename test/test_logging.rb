# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq2/logging'

class TestLogging < Sidekiq2::Test
  describe Sidekiq2::Logging do
    describe "#with_context" do
      def ctx
        Sidekiq2::Logging.logger.formatter.context
      end

      it "has no context by default" do
        assert_nil ctx
      end

      it "can add a context" do
        Sidekiq2::Logging.with_context "xx" do
          assert_equal " xx", ctx
        end
        assert_nil ctx
      end

      it "can use multiple contexts" do
        Sidekiq2::Logging.with_context "xx" do
          assert_equal " xx", ctx
          Sidekiq2::Logging.with_context "yy" do
            assert_equal " xx yy", ctx
          end
          assert_equal " xx", ctx
        end
        assert_nil ctx
      end
    end
  end
end
