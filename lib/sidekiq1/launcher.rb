# frozen_string_literal: true
require 'sidekiq1/manager'
require 'sidekiq1/fetch'
require 'sidekiq1/scheduled'

module Sidekiq1
  # The Launcher is a very simple Actor whose job is to
  # start, monitor and stop the core Actors in Sidekiq1.
  # If any of these actors die, the Sidekiq1 process exits
  # immediately.
  class Launcher
    include Util

    attr_accessor :manager, :poller, :fetcher

    STATS_TTL = 5*365*24*60*60

    def initialize(options)
      @manager = Sidekiq1::Manager.new(options)
      @poller = Sidekiq1::Scheduled::Poller.new
      @done = false
      @options = options
    end

    def run
      @thread = safe_thread("heartbeat", &method(:start_heartbeat))
      @poller.start
      @manager.start
    end

    # Stops this instance from processing any more jobs,
    #
    def quiet
      @done = true
      @manager.quiet
      @poller.terminate
    end

    # Shuts down the process.  This method does not
    # return until all work is complete and cleaned up.
    # It can take up to the timeout to complete.
    def stop
      deadline = Time.now + @options[:timeout]

      @done = true
      @manager.quiet
      @poller.terminate

      @manager.stop(deadline)

      # Requeue everything in case there was a worker who grabbed work while stopped
      # This call is a no-op in Sidekiq1 but necessary for Sidekiq1 Pro.
      strategy = (@options[:fetch] || Sidekiq1::BasicFetch)
      strategy.bulk_requeue([], @options)

      clear_heartbeat
    end

    def stopping?
      @done
    end

    private unless $TESTING

    def heartbeat
      results = Sidekiq1::CLI::PROCTITLES.map {|x| x.(self, to_data) }
      results.compact!
      $0 = results.join(' ')

      ❤
    end

    def ❤
      key = identity
      fails = procd = 0
      begin
        fails = Processor::FAILURE.reset
        procd = Processor::PROCESSED.reset
        curstate = Processor::WORKER_STATE.dup

        workers_key = "#{key}:workers"
        nowdate = Time.now.utc.strftime("%Y-%m-%d")
        Sidekiq1.redis do |conn|
          conn.multi do
            conn.incrby("stat:processed", procd)
            conn.incrby("stat:processed:#{nowdate}", procd)
            conn.expire("stat:processed:#{nowdate}", STATS_TTL)

            conn.incrby("stat:failed", fails)
            conn.incrby("stat:failed:#{nowdate}", fails)
            conn.expire("stat:failed:#{nowdate}", STATS_TTL)

            conn.del(workers_key)
            curstate.each_pair do |tid, hash|
              conn.hset(workers_key, tid, Sidekiq1.dump_json(hash))
            end
            conn.expire(workers_key, 60)
          end
        end
        fails = procd = 0

        _, exists, _, _, msg = Sidekiq1.redis do |conn|
          conn.multi do
            conn.sadd('processes', key)
            conn.exists(key)
            conn.hmset(key, 'info', to_json, 'busy', curstate.size, 'beat', Time.now.to_f, 'quiet', @done)
            conn.expire(key, 60)
            conn.rpop("#{key}-signals")
          end
        end

        # first heartbeat or recovering from an outage and need to reestablish our heartbeat
        fire_event(:heartbeat) if !exists

        return unless msg

        ::Process.kill(msg, $$)
      rescue => e
        # ignore all redis/network issues
        logger.error("heartbeat: #{e.message}")
        # don't lose the counts if there was a network issue
        Processor::PROCESSED.incr(procd)
        Processor::FAILURE.incr(fails)
      end
    end

    def start_heartbeat
      while true
        heartbeat
        sleep 5
      end
      Sidekiq1.logger.info("Heartbeat stopping...")
    end

    def to_data
      @data ||= begin
        {
          'hostname' => hostname,
          'started_at' => Time.now.to_f,
          'pid' => $$,
          'tag' => @options[:tag] || '',
          'concurrency' => @options[:concurrency],
          'queues' => @options[:queues].uniq,
          'labels' => @options[:labels],
          'identity' => identity,
        }
      end
    end

    def to_json
      @json ||= begin
        # this data changes infrequently so dump it to a string
        # now so we don't need to dump it every heartbeat.
        Sidekiq1.dump_json(to_data)
      end
    end

    def clear_heartbeat
      # Remove record from Redis since we are shutting down.
      # Note we don't stop the heartbeat thread; if the process
      # doesn't actually exit, it'll reappear in the Web UI.
      Sidekiq1.redis do |conn|
        conn.pipelined do
          conn.srem('processes', identity)
          conn.del("#{identity}:workers")
        end
      end
    rescue
      # best effort, ignore network errors
    end

  end
end
