class ExitWorker
  include Sidekiq2::Worker

  def perform
    logger.warn "Success"
    Thread.new do
      sleep 0.1
      exit(0)
    end
  end
end
