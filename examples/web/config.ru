require 'sidekiq/web'
require 'redis'

$redis = Redis.new

class SinatraWorker
  include Sidekiq2::Worker

  def perform(msg="lulz you forgot a msg!")
    $redis.lpush("sinkiq-example-messages", msg)
  end
end

run Sidekiq2::Web
