# frozen_string_literal: true
require_relative 'helper'

class TestUtil < Sidekiq2::Test

  class Helpers
    include Sidekiq2::Util
  end

  def test_event_firing
    Sidekiq2.options[:lifecycle_events][:startup] = [proc { raise "boom" }]
    h = Helpers.new
    h.fire_event(:startup)

    Sidekiq2.options[:lifecycle_events][:startup] = [proc { raise "boom" }]
    assert_raises RuntimeError do
      h.fire_event(:startup, reraise: true)
    end
  end
end
