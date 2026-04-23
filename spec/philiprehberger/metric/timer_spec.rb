# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Metric::Timer do
  let(:registry) { Philiprehberger::Metric::Registry.new }

  before do
    registry.histogram('op_duration', help: 'Operation duration', buckets: [0.001, 0.01, 0.1, 1])
  end

  describe '#elapsed' do
    it 'returns a positive float before the timer is stopped' do
      timer = described_class.new('op_duration', registry: registry)
      sleep 0.001
      elapsed = timer.elapsed

      expect(elapsed).to be_a(Float)
      expect(elapsed).to be > 0
    end

    it 'returns the cached elapsed value after stop' do
      timer = described_class.new('op_duration', registry: registry)
      sleep 0.001
      recorded = timer.stop

      expect(timer.elapsed).to eq(recorded)
    end
  end

  describe '#stop' do
    it 'records the elapsed time into the histogram via the registry' do
      timer = described_class.new('op_duration', registry: registry)
      sleep 0.001
      recorded = timer.stop

      data = registry.get('op_duration').get
      expect(data[:count]).to eq(1)
      expect(data[:sum]).to be_within(0.0001).of(recorded)
    end

    it 'returns the elapsed seconds as a Float' do
      timer = described_class.new('op_duration', registry: registry)
      result = timer.stop

      expect(result).to be_a(Float)
      expect(result).to be >= 0
    end

    it 'forwards labels to the histogram observation' do
      timer = described_class.new('op_duration', registry: registry)
      timer.stop(labels: { op: 'compute' })

      labeled_data = registry.get('op_duration').get(labels: { op: 'compute' })
      unlabeled_data = registry.get('op_duration').get

      expect(labeled_data[:count]).to eq(1)
      expect(unlabeled_data[:count]).to eq(0)
    end

    it 'is idempotent: calling stop twice records only once and returns the cached value' do
      timer = described_class.new('op_duration', registry: registry)
      first = timer.stop
      second = timer.stop

      expect(second).to eq(first)
      expect(registry.get('op_duration').get[:count]).to eq(1)
    end

    it 'raises when called after explicit reset' do
      timer = described_class.new('op_duration', registry: registry)
      timer.reset

      expect { timer.stop }.to raise_error(Philiprehberger::Metric::Error, /reset/)
    end

    it 'defaults to the global registry when no registry is passed' do
      Philiprehberger::Metric.reset
      Philiprehberger::Metric.histogram('default_timer_hist', help: 'Default registry timer', buckets: [1])

      timer = described_class.new('default_timer_hist')
      timer.stop

      expect(Philiprehberger::Metric.snapshot('default_timer_hist')[{}][:count]).to eq(1)
    ensure
      Philiprehberger::Metric.reset
    end
  end

  describe '#reset' do
    it 'clears the stopped state and records no additional observation' do
      timer = described_class.new('op_duration', registry: registry)
      timer.stop
      timer.reset

      expect(registry.get('op_duration').get[:count]).to eq(1)
    end

    it 'leaves the timer unable to stop until re-constructed' do
      timer = described_class.new('op_duration', registry: registry)
      timer.reset

      expect { timer.stop }.to raise_error(Philiprehberger::Metric::Error)
    end
  end
end
