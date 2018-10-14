# frozen_string_literal: true
require_relative 'helper'

class TestUtil < Sidekiq1::Test

  class Helpers
    include Sidekiq1::Util
  end

  def test_event_firing
    Sidekiq1.options[:lifecycle_events][:startup] = [proc { raise "boom" }]
    h = Helpers.new
    h.fire_event(:startup)

    Sidekiq1.options[:lifecycle_events][:startup] = [proc { raise "boom" }]
    assert_raises RuntimeError do
      h.fire_event(:startup, reraise: true)
    end
  end
end
