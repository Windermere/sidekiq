# frozen_string_literal: true
module Sidekiq1
  class Rails < ::Rails::Engine
    # We need to setup this up before any application configuration which might
    # change Sidekiq1 middleware.
    #
    # This hook happens after `Rails::Application` is inherited within
    # config/application.rb and before config is touched, usually within the
    # class block. Definitely before config/environments/*.rb and
    # config/initializers/*.rb.
    config.before_configuration do
      if ::Rails::VERSION::MAJOR < 5 && defined?(::ActiveRecord)
        Sidekiq1.server_middleware do |chain|
          require 'sidekiq1/middleware/server/active_record'
          chain.add Sidekiq1::Middleware::Server::ActiveRecord
        end
      end
    end

    config.after_initialize do
      # This hook happens after all initializers are run, just before returning
      # from config/environment.rb back to sidekiq/cli.rb.
      # We have to add the reloader after initialize to see if cache_classes has
      # been turned on.
      #
      # None of this matters on the client-side, only within the Sidekiq1 process itself.
      #
      Sidekiq1.configure_server do |_|
        if ::Rails::VERSION::MAJOR >= 5
          Sidekiq1.options[:reloader] = Sidekiq1::Rails::Reloader.new
        end
      end
    end

    class Reloader
      def initialize(app = ::Rails.application)
        @app = app
      end

      def call
        @app.reloader.wrap do
          yield
        end
      end

      def inspect
        "#<Sidekiq1::Rails::Reloader @app=#{@app.class.name}>"
      end
    end
  end if defined?(::Rails)
end

if defined?(::Rails) && ::Rails::VERSION::MAJOR < 4
  $stderr.puts("**************************************************")
  $stderr.puts("⛔️ WARNING: Sidekiq1 server is no longer supported by Rails 3.2 - please ensure your server/workers are updated")
  $stderr.puts("**************************************************")
end
