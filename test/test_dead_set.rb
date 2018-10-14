# frozen_string_literal: true
require_relative 'helper'
require 'sidekiq2/api'

class TestDeadSet < Sidekiq2::Test
  describe 'dead_set' do
    describe 'zomg' do
      def dead_set
        Sidekiq2::DeadSet.new
      end

      it 'should put passed serialized job to the "dead" sorted set' do
        serialized_job = Sidekiq2.dump_json(jid: '123123', class: 'SomeWorker', args: [])
        dead_set.kill(serialized_job)

        assert_equal dead_set.find_job('123123').value, serialized_job
      end

      it 'should remove dead jobs older than Sidekiq2::DeadSet.timeout' do
        Sidekiq2::DeadSet.stub(:timeout, 10) do
          Time.stub(:now, Time.now - 11) do
            dead_set.kill(Sidekiq2.dump_json(jid: '000103', class: 'MyWorker3', args: [])) # the oldest
          end

          Time.stub(:now, Time.now - 9) do
            dead_set.kill(Sidekiq2.dump_json(jid: '000102', class: 'MyWorker2', args: []))
          end

          dead_set.kill(Sidekiq2.dump_json(jid: '000101', class: 'MyWorker1', args: []))
        end

        assert_nil dead_set.find_job('000103')
        assert dead_set.find_job('000102')
        assert dead_set.find_job('000101')
      end

      it 'should remove all but last Sidekiq2::DeadSet.max_jobs-1 jobs' do
        Sidekiq2::DeadSet.stub(:max_jobs, 3) do
          dead_set.kill(Sidekiq2.dump_json(jid: '000101', class: 'MyWorker1', args: []))
          dead_set.kill(Sidekiq2.dump_json(jid: '000102', class: 'MyWorker2', args: []))
          dead_set.kill(Sidekiq2.dump_json(jid: '000103', class: 'MyWorker3', args: []))
        end

        assert_nil dead_set.find_job('000101')
        assert dead_set.find_job('000102')
        assert dead_set.find_job('000103')
      end
    end
  end
end
