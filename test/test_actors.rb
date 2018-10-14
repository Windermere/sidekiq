# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq2/cli'
require 'sidekiq2/fetch'
require 'sidekiq2/scheduled'
require 'sidekiq2/processor'

class TestActors < Sidekiq2::Test
  class JoeWorker
    include Sidekiq2::Worker
    def perform(slp)
      raise "boom" if slp == "boom"
      sleep(slp) if slp > 0
      $count += 1
    end
  end

  describe 'threads' do
    before do
      Sidekiq2.redis {|c| c.flushdb}
    end

    describe 'scheduler' do
      it 'can start and stop' do
        f = Sidekiq2::Scheduled::Poller.new
        f.start
        f.terminate
      end

      it 'can schedule' do
        ss = Sidekiq2::ScheduledSet.new
        q = Sidekiq2::Queue.new

        JoeWorker.perform_in(0.01, 0)

        assert_equal 0, q.size
        assert_equal 1, ss.size

        sleep 0.015
        s = Sidekiq2::Scheduled::Poller.new
        s.enqueue
        assert_equal 1, q.size
        assert_equal 0, ss.size
        s.terminate
      end
    end

    describe 'processor' do
      before do
        $count = 0
      end

      it 'can start and stop' do
        f = Sidekiq2::Processor.new(Mgr.new)
        f.terminate
      end

      class Mgr
        attr_reader :latest_error
        attr_reader :mutex
        attr_reader :cond
        def initialize
          @mutex = ::Mutex.new
          @cond = ::ConditionVariable.new
        end
        def processor_died(inst, err)
          @latest_error = err
          @mutex.synchronize do
            @cond.signal
          end
        end
        def processor_stopped(inst)
          @mutex.synchronize do
            @cond.signal
          end
        end
        def options
          { :concurrency => 3, :queues => ['default'] }
        end
      end

      it 'can process' do
        mgr = Mgr.new

        p = Sidekiq2::Processor.new(mgr)
        JoeWorker.perform_async(0)

        a = $count
        p.process_one
        b = $count
        assert_equal a + 1, b
      end

      it 'deals with errors' do
        mgr = Mgr.new

        p = Sidekiq2::Processor.new(mgr)
        JoeWorker.perform_async("boom")
        q = Sidekiq2::Queue.new
        assert_equal 1, q.size

        a = $count
        mgr.mutex.synchronize do
          p.start
          mgr.cond.wait(mgr.mutex)
        end
        b = $count
        assert_equal a, b

        sleep 0.001
        assert_equal false, p.thread.status
        p.terminate(true)
        refute_nil mgr.latest_error
        assert_equal RuntimeError, mgr.latest_error.class
      end

      it 'gracefully kills' do
        mgr = Mgr.new

        p = Sidekiq2::Processor.new(mgr)
        JoeWorker.perform_async(1)
        q = Sidekiq2::Queue.new
        assert_equal 1, q.size

        a = $count
        p.start
        sleep(0.05)
        p.terminate
        p.kill(true)

        b = $count
        assert_equal a, b
        assert_equal false, p.thread.status
        refute mgr.latest_error, mgr.latest_error.to_s
      end
    end
  end
end
