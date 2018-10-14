# frozen_string_literal: true
$TESTING = true
# disable minitest/parallel threads
ENV["N"] = "0"

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/myapp/"
  end
end
ENV['RACK_ENV'] = ENV['RAILS_ENV'] = 'test'

trap 'TSTP' do
  threads = Thread.list

  puts
  puts "=" * 80
  puts "Received TSTP signal; printing all #{threads.count} thread backtraces."

  threads.each do |thr|
    description = thr == Thread.main ? "Main thread" : thr.inspect
    puts
    puts "#{description} backtrace: "
    puts thr.backtrace.join("\n")
  end

  puts "=" * 80
end

begin
  require 'pry-byebug'
rescue LoadError
end

require 'minitest/autorun'

require 'sidekiq'
require 'sidekiq2/util'
Sidekiq2.logger.level = Logger::ERROR

Sidekiq2::Test = Minitest::Test

require 'sidekiq2/redis_connection'
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost/15'
REDIS = Sidekiq2::RedisConnection.create(:url => REDIS_URL)

Sidekiq2.configure_client do |config|
  config.redis = { :url => REDIS_URL }
end

def capture_logging(lvl=Logger::INFO)
  old = Sidekiq2.logger
  begin
    out = StringIO.new
    logger = Logger.new(out)
    logger.level = lvl
    Sidekiq2.logger = logger
    yield
    out.string
  ensure
    Sidekiq2.logger = old
  end
end

def with_logging(lvl=Logger::DEBUG)
  old = Sidekiq2.logger.level
  begin
    Sidekiq2.logger.level = lvl
    yield
  ensure
    Sidekiq2.logger.level = old
  end
end
