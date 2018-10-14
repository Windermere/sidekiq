class LazyWorker
  include Sidekiq1::Worker

  def perform
  end
end
