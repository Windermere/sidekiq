# frozen_string_literal: true
require_relative 'helper'

class TestTesting < Sidekiq1::Test
  describe 'sidekiq testing' do
    describe 'require/load sidekiq/testing.rb' do
      before do
        require 'sidekiq1/testing'
      end

      after do
        Sidekiq1::Testing.disable!
      end

      it 'enables fake testing' do
        Sidekiq1::Testing.fake!
        assert Sidekiq1::Testing.enabled?
        assert Sidekiq1::Testing.fake?
        refute Sidekiq1::Testing.inline?
      end

      it 'enables fake testing in a block' do
        Sidekiq1::Testing.disable!
        assert Sidekiq1::Testing.disabled?
        refute Sidekiq1::Testing.fake?

        Sidekiq1::Testing.fake! do
          assert Sidekiq1::Testing.enabled?
          assert Sidekiq1::Testing.fake?
          refute Sidekiq1::Testing.inline?
        end

        refute Sidekiq1::Testing.enabled?
        refute Sidekiq1::Testing.fake?
      end

      it 'disables testing in a block' do
        Sidekiq1::Testing.fake!
        assert Sidekiq1::Testing.fake?

        Sidekiq1::Testing.disable! do
          refute Sidekiq1::Testing.fake?
          assert Sidekiq1::Testing.disabled?
        end

        assert Sidekiq1::Testing.fake?
        assert Sidekiq1::Testing.enabled?
      end
    end

    describe 'require/load sidekiq/testing/inline.rb' do
      before do
        require 'sidekiq1/testing/inline'
      end

      after do
        Sidekiq1::Testing.disable!
      end

      it 'enables inline testing' do
        Sidekiq1::Testing.inline!
        assert Sidekiq1::Testing.enabled?
        assert Sidekiq1::Testing.inline?
        refute Sidekiq1::Testing.fake?
      end

      it 'enables inline testing in a block' do
        Sidekiq1::Testing.disable!
        assert Sidekiq1::Testing.disabled?
        refute Sidekiq1::Testing.fake?

        Sidekiq1::Testing.inline! do
          assert Sidekiq1::Testing.enabled?
          assert Sidekiq1::Testing.inline?
        end

        refute Sidekiq1::Testing.enabled?
        refute Sidekiq1::Testing.inline?
        refute Sidekiq1::Testing.fake?
      end
    end
  end

  describe 'with middleware' do
    before do
      require 'sidekiq1/testing'
    end

    after do
      Sidekiq1::Testing.disable!
    end

    class AttributeWorker
      include Sidekiq1::Worker
      sidekiq_class_attribute :count
      self.count = 0
      attr_accessor :foo

      def perform
        self.class.count += 1 if foo == :bar
      end
    end

    class AttributeMiddleware
      def call(worker, msg, queue)
        worker.foo = :bar if worker.respond_to?(:foo=)
        yield
      end
    end

    it 'wraps the inlined worker with middleware' do
      Sidekiq1::Testing.server_middleware do |chain|
        chain.add AttributeMiddleware
      end

      begin
        Sidekiq1::Testing.fake! do
          AttributeWorker.perform_async
          assert_equal 0, AttributeWorker.count
        end

        AttributeWorker.perform_one
        assert_equal 1, AttributeWorker.count

        Sidekiq1::Testing.inline! do
          AttributeWorker.perform_async
          assert_equal 2, AttributeWorker.count
        end
      ensure
        Sidekiq1::Testing.server_middleware.clear
      end
    end
  end

end
