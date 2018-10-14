# frozen_string_literal: true
require 'sidekiq1'

module Sidekiq1
  module ExceptionHandler

    class Logger
      def call(ex, ctxHash)
        Sidekiq1.logger.warn(Sidekiq1.dump_json(ctxHash)) if !ctxHash.empty?
        Sidekiq1.logger.warn("#{ex.class.name}: #{ex.message}")
        Sidekiq1.logger.warn(ex.backtrace.join("\n")) unless ex.backtrace.nil?
      end

      Sidekiq1.error_handlers << Sidekiq1::ExceptionHandler::Logger.new
    end

    def handle_exception(ex, ctxHash={})
      Sidekiq1.error_handlers.each do |handler|
        begin
          handler.call(ex, ctxHash)
        rescue => ex
          Sidekiq1.logger.error "!!! ERROR HANDLER THREW AN ERROR !!!"
          Sidekiq1.logger.error ex
          Sidekiq1.logger.error ex.backtrace.join("\n") unless ex.backtrace.nil?
        end
      end
    end
  end
end
