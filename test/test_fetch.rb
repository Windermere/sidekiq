# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq1/fetch'

class TestFetcher < Sidekiq1::Test
  describe 'fetcher' do
    before do
      Sidekiq1.redis = { :url => REDIS_URL }
      Sidekiq1.redis do |conn|
        conn.flushdb
        conn.rpush('queue:basic', 'msg')
      end
    end

    after do
      Sidekiq1.redis = REDIS
    end

    it 'retrieves' do
      fetch = Sidekiq1::BasicFetch.new(:queues => ['basic', 'bar'])
      uow = fetch.retrieve_work
      refute_nil uow
      assert_equal 'basic', uow.queue_name
      assert_equal 'msg', uow.job
      q = Sidekiq1::Queue.new('basic')
      assert_equal 0, q.size
      uow.requeue
      assert_equal 1, q.size
      assert_nil uow.acknowledge
    end

    it 'retrieves with strict setting' do
      fetch = Sidekiq1::BasicFetch.new(:queues => ['basic', 'bar', 'bar'], :strict => true)
      cmd = fetch.queues_cmd
      assert_equal cmd, ['queue:basic', 'queue:bar', Sidekiq1::BasicFetch::TIMEOUT]
    end

    it 'bulk requeues' do
      q1 = Sidekiq1::Queue.new('foo')
      q2 = Sidekiq1::Queue.new('bar')
      assert_equal 0, q1.size
      assert_equal 0, q2.size
      uow = Sidekiq1::BasicFetch::UnitOfWork
      Sidekiq1::BasicFetch.bulk_requeue([uow.new('fuzzy:queue:foo', 'bob'), uow.new('fuzzy:queue:foo', 'bar'), uow.new('fuzzy:queue:bar', 'widget')], {:queues => []})
      assert_equal 2, q1.size
      assert_equal 1, q2.size
    end

  end
end
