# encoding: utf-8
# frozen_string_literal: true
require_relative 'helper'

class TestSidekiq < Sidekiq2::Test
  describe 'json processing' do
    it 'handles json' do
      assert_equal({"foo" => "bar"}, Sidekiq2.load_json("{\"foo\":\"bar\"}"))
      assert_equal "{\"foo\":\"bar\"}", Sidekiq2.dump_json({ "foo" => "bar" })
    end
  end

  describe "redis connection" do
  	it "returns error without creating a connection if block is not given" do
  		assert_raises(ArgumentError) do
  			Sidekiq2.redis
      end
  	end
  end

  describe "❨╯°□°❩╯︵┻━┻" do
    before { $stdout = StringIO.new }
    after  { $stdout = STDOUT }

    it "allows angry developers to express their emotional constitution and remedies it" do
      Sidekiq2.❨╯°□°❩╯︵┻━┻
      assert_equal "Calm down, yo.\n", $stdout.string
    end
  end

  describe 'lifecycle events' do
    it 'handles invalid input' do
      Sidekiq2.options[:lifecycle_events][:startup].clear

      e = assert_raises ArgumentError do
        Sidekiq2.on(:startp)
      end
      assert_match(/Invalid event name/, e.message)
      e = assert_raises ArgumentError do
        Sidekiq2.on('startup')
      end
      assert_match(/Symbols only/, e.message)
      Sidekiq2.on(:startup) do
        1 + 1
      end

      assert_equal 2, Sidekiq2.options[:lifecycle_events][:startup].first.call
    end
  end

  describe 'default_worker_options' do
    it 'stringifies keys' do
      @old_options = Sidekiq2.default_worker_options
      begin
        Sidekiq2.default_worker_options = { queue: 'cat'}
        assert_equal 'cat', Sidekiq2.default_worker_options['queue']
      ensure
        Sidekiq2.default_worker_options = @old_options
      end
    end
  end

  describe 'error handling' do
    it 'deals with user-specified error handlers which raise errors' do
      output = capture_logging do
        begin
          Sidekiq2.error_handlers << proc {|x, hash|
            raise 'boom'
          }
          cli = Sidekiq2::CLI.new
          cli.handle_exception(RuntimeError.new("hello"))
        ensure
          Sidekiq2.error_handlers.pop
        end
      end
      assert_includes output, "boom"
      assert_includes output, "ERROR"
    end
  end

  describe 'redis connection' do
    it 'does not continually retry' do
      assert_raises Redis::CommandError do
        Sidekiq2.redis do |c|
          raise Redis::CommandError, "READONLY You can't write against a read only slave."
        end
      end
    end

    it 'reconnects if connection is flagged as readonly' do
      counts = []
      Sidekiq2.redis do |c|
        counts << c.info['total_connections_received'].to_i
        raise Redis::CommandError, "READONLY You can't write against a read only slave." if counts.size == 1
      end
      assert_equal 2, counts.size
      assert_equal counts[0] + 1, counts[1]
    end
  end

  describe 'redis info' do
    it 'calls the INFO command which returns at least redis_version' do
      output = Sidekiq2.redis_info
      assert_includes output.keys, "redis_version"
    end
  end
end
