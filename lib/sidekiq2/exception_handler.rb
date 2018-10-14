# frozen_string_literal: true
require 'sidekiq2'

module Sidekiq2
  module ExceptionHandler

    class Logger
      def call(ex, ctxHash)
        Sidekiq2.logger.warn(Sidekiq2.dump_json(ctxHash)) if !ctxHash.empty?
        Sidekiq2.logger.warn("#{ex.class.name}: #{ex.message}")
        Sidekiq2.logger.warn(ex.backtrace.join("\n")) unless ex.backtrace.nil?
      end

      Sidekiq2.error_handlers << Sidekiq2::ExceptionHandler::Logger.new
    end

    def handle_exception(ex, ctxHash={})
      Sidekiq2.error_handlers.each do |handler|
        begin
          handler.call(ex, ctxHash)
        rescue => ex
          Sidekiq2.logger.error "!!! ERROR HANDLER THREW AN ERROR !!!"
          Sidekiq2.logger.error ex
          Sidekiq2.logger.error ex.backtrace.join("\n") unless ex.backtrace.nil?
        end
      end
    end
  end
end
