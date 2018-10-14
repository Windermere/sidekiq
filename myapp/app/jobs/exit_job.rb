class ExitJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Sidekiq2.logger.warn "Success"
    Thread.new do
      sleep 0.1
      exit(0)
    end
  end
end
