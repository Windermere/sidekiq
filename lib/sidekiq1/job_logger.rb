# frozen_string_literal: true
module Sidekiq1
  class JobLogger

    def call(item, queue)
      start = Time.now
      logger.info("start")
      yield
      logger.info("done: #{elapsed(start)} sec")
    rescue Exception
      logger.info("fail: #{elapsed(start)} sec")
      raise
    end

    private

    def elapsed(start)
      (Time.now - start).round(3)
    end

    def logger
      Sidekiq1.logger
    end
  end
end
