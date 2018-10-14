class LazyWorker
  include Sidekiq2::Worker

  def perform
  end
end
