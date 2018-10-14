# frozen_string_literal: true
#
# Simple middleware to save the current locale and restore it when the job executes.
# Use it by requiring it in your initializer:
#
#     require 'sidekiq2/middleware/i18n'
#
module Sidekiq2::Middleware::I18n
  # Get the current locale and store it in the message
  # to be sent to Sidekiq2.
  class Client
    def call(worker_class, msg, queue, redis_pool)
      msg['locale'] ||= I18n.locale
      yield
    end
  end

  # Pull the msg locale out and set the current thread to use it.
  class Server
    def call(worker, msg, queue)
      I18n.locale = msg['locale'] || I18n.default_locale
      yield
    ensure
      I18n.locale = I18n.default_locale
    end
  end
end

Sidekiq2.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq2::Middleware::I18n::Client
  end
end

Sidekiq2.configure_server do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq2::Middleware::I18n::Client
  end
  config.server_middleware do |chain|
    chain.add Sidekiq2::Middleware::I18n::Server
  end
end
