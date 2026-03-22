# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Philiprehberger::Metric do
  before { described_class.reset }

  it 'has a version number' do
    expect(Philiprehberger::Metric::VERSION).not_to be_nil
  end

  describe 'counter' do
    it 'registers and increments a counter' do
      described_class.counter('http_requests_total', help: 'Total HTTP requests')
      described_class.increment('http_requests_total')
      described_class.increment('http_requests_total')

      counter = described_class.get('http_requests_total')
      expect(counter.get).to eq(2)
    end

    it 'supports labels' do
      described_class.counter('requests', help: 'Requests')
      described_class.increment('requests', labels: { method: 'GET' })
      described_class.increment('requests', labels: { method: 'POST' })
      described_class.increment('requests', labels: { method: 'GET' })

      counter = described_class.get('requests')
      expect(counter.get(labels: { method: 'GET' })).to eq(2)
      expect(counter.get(labels: { method: 'POST' })).to eq(1)
    end

    it 'returns 0 for untracked labels' do
      described_class.counter('hits', help: 'Hits')
      counter = described_class.get('hits')

      expect(counter.get(labels: { page: '/unknown' })).to eq(0)
    end

    it 'increments by a custom amount' do
      described_class.counter('bytes', help: 'Bytes')
      counter = described_class.get('bytes')
      counter.increment(amount: 100)
      counter.increment(amount: 50)

      expect(counter.get).to eq(150)
    end

    it 'returns the correct type' do
      described_class.counter('test_type', help: 'Type test')
      counter = described_class.get('test_type')
      expect(counter.type).to eq('counter')
    end

    it 'resets counter values' do
      described_class.counter('resettable', help: 'Resettable')
      counter = described_class.get('resettable')
      counter.increment
      counter.reset

      expect(counter.get).to eq(0)
      expect(counter.snapshot).to eq({})
    end

    it 'treats label order consistently' do
      described_class.counter('ordered', help: 'Ordered')
      counter = described_class.get('ordered')
      counter.increment(labels: { b: '2', a: '1' })
      counter.increment(labels: { a: '1', b: '2' })

      expect(counter.get(labels: { a: '1', b: '2' })).to eq(2)
    end
  end

  describe 'gauge' do
    it 'registers and sets a gauge' do
      described_class.gauge('temperature', help: 'Current temperature')
      described_class.set('temperature', 72.5)

      gauge = described_class.get('temperature')
      expect(gauge.get).to eq(72.5)
    end

    it 'supports increment and decrement' do
      described_class.gauge('active_connections', help: 'Active connections')
      gauge = described_class.get('active_connections')
      gauge.increment
      gauge.increment
      gauge.decrement

      expect(gauge.get).to eq(1)
    end

    it 'decrements by custom amount' do
      described_class.gauge('level', help: 'Level')
      gauge = described_class.get('level')
      gauge.set(100)
      gauge.decrement(amount: 25)

      expect(gauge.get).to eq(75)
    end

    it 'increments by custom amount' do
      described_class.gauge('score', help: 'Score')
      gauge = described_class.get('score')
      gauge.increment(amount: 10)

      expect(gauge.get).to eq(10)
    end

    it 'supports negative gauge values' do
      described_class.gauge('delta', help: 'Delta')
      gauge = described_class.get('delta')
      gauge.set(-5)

      expect(gauge.get).to eq(-5)
    end

    it 'supports labels on gauge' do
      described_class.gauge('mem', help: 'Memory')
      gauge = described_class.get('mem')
      gauge.set(100, labels: { host: 'a' })
      gauge.set(200, labels: { host: 'b' })

      expect(gauge.get(labels: { host: 'a' })).to eq(100)
      expect(gauge.get(labels: { host: 'b' })).to eq(200)
    end

    it 'returns the correct type' do
      described_class.gauge('type_test', help: 'Type test')
      expect(described_class.get('type_test').type).to eq('gauge')
    end

    it 'resets gauge values' do
      described_class.gauge('resettable_g', help: 'Resettable')
      gauge = described_class.get('resettable_g')
      gauge.set(42)
      gauge.reset

      expect(gauge.get).to eq(0)
      expect(gauge.snapshot).to eq({})
    end
  end

  describe 'histogram' do
    it 'registers and observes values' do
      described_class.histogram('request_duration', help: 'Request duration', buckets: [0.1, 0.5, 1, 5])
      described_class.observe('request_duration', 0.3)
      described_class.observe('request_duration', 0.8)
      described_class.observe('request_duration', 2.0)

      histogram = described_class.get('request_duration')
      data = histogram.get
      expect(data[:count]).to eq(3)
      expect(data[:sum]).to be_within(0.001).of(3.1)
      expect(data[:buckets][0.1]).to eq(0)
      expect(data[:buckets][0.5]).to eq(1)
      expect(data[:buckets][1]).to eq(2)
      expect(data[:buckets][5]).to eq(3)
    end

    it 'returns empty data for unobserved labels' do
      described_class.histogram('lat', help: 'Latency', buckets: [1])
      histogram = described_class.get('lat')
      data = histogram.get(labels: { path: '/unknown' })

      expect(data[:count]).to eq(0)
      expect(data[:sum]).to eq(0.0)
      expect(data[:buckets]).to eq({})
    end

    it 'uses default buckets when none specified' do
      described_class.histogram('default_buckets', help: 'Default')
      histogram = described_class.get('default_buckets')
      expect(histogram.buckets).to eq(Philiprehberger::Metric::Histogram::DEFAULT_BUCKETS)
    end

    it 'sorts custom buckets' do
      described_class.histogram('sorted', help: 'Sorted', buckets: [10, 1, 5])
      histogram = described_class.get('sorted')
      expect(histogram.buckets).to eq([1, 5, 10])
    end

    it 'supports labels on histogram' do
      described_class.histogram('labeled_hist', help: 'Labeled', buckets: [1, 10])
      histogram = described_class.get('labeled_hist')
      histogram.observe(5, labels: { method: 'GET' })
      histogram.observe(0.5, labels: { method: 'POST' })

      get_data = histogram.get(labels: { method: 'GET' })
      post_data = histogram.get(labels: { method: 'POST' })

      expect(get_data[:count]).to eq(1)
      expect(post_data[:count]).to eq(1)
    end

    it 'returns the correct type' do
      described_class.histogram('type_h', help: 'Type')
      expect(described_class.get('type_h').type).to eq('histogram')
    end

    it 'resets histogram observations' do
      described_class.histogram('resettable_h', help: 'R', buckets: [1])
      histogram = described_class.get('resettable_h')
      histogram.observe(0.5)
      histogram.reset

      expect(histogram.get[:count]).to eq(0)
      expect(histogram.snapshot).to eq({})
    end
  end

  describe '.snapshot' do
    it 'returns a snapshot of metric values' do
      described_class.counter('visits', help: 'Page visits')
      described_class.increment('visits', labels: { page: '/' })
      described_class.increment('visits', labels: { page: '/about' })

      snap = described_class.snapshot('visits')
      expect(snap.size).to eq(2)
    end
  end

  describe '.to_prometheus' do
    it 'exports metrics in Prometheus format' do
      described_class.counter('http_total', help: 'Total requests')
      described_class.increment('http_total', labels: { status: '200' })

      output = described_class.to_prometheus
      expect(output).to include('# HELP http_total Total requests')
      expect(output).to include('# TYPE http_total counter')
      expect(output).to include('http_total{status="200"} 1')
    end

    it 'exports histogram metrics' do
      described_class.histogram('duration', help: 'Duration', buckets: [0.1, 1])
      described_class.observe('duration', 0.5)

      output = described_class.to_prometheus
      expect(output).to include('# TYPE duration histogram')
      expect(output).to include('duration_bucket')
      expect(output).to include('duration_sum')
      expect(output).to include('duration_count')
    end

    it 'exports counter without labels' do
      described_class.counter('simple', help: 'Simple counter')
      described_class.increment('simple')

      output = described_class.to_prometheus
      expect(output).to include('simple{} 1')
    end

    it 'exports gauge in Prometheus format' do
      described_class.gauge('temp', help: 'Temperature')
      described_class.set('temp', 72.5, labels: { room: 'office' })

      output = described_class.to_prometheus
      expect(output).to include('# TYPE temp gauge')
      expect(output).to include('temp{room="office"} 72.5')
    end

    it 'returns a trailing newline' do
      described_class.counter('nl', help: 'Newline test')
      output = described_class.to_prometheus
      expect(output).to end_with("\n")
    end
  end

  describe '.to_json' do
    it 'exports metrics as JSON' do
      described_class.counter('events', help: 'Events')
      described_class.increment('events')

      json = described_class.to_json
      data = JSON.parse(json)
      expect(data).to have_key('events')
      expect(data['events']['type']).to eq('counter')
    end

    it 'includes help text in JSON output' do
      described_class.counter('with_help', help: 'A helpful description')
      described_class.increment('with_help')

      data = JSON.parse(described_class.to_json)
      expect(data['with_help']['help']).to eq('A helpful description')
    end

    it 'exports multiple metrics as JSON' do
      described_class.counter('c1', help: 'Counter 1')
      described_class.gauge('g1', help: 'Gauge 1')

      data = JSON.parse(described_class.to_json)
      expect(data.keys).to contain_exactly('c1', 'g1')
    end
  end

  describe '.reset' do
    it 'clears all metrics' do
      described_class.counter('test_counter', help: 'Test')
      described_class.increment('test_counter')
      described_class.reset

      expect { described_class.get('test_counter') }.to raise_error(Philiprehberger::Metric::Error)
    end
  end

  describe 'error handling' do
    it 'raises on duplicate metric registration' do
      described_class.counter('dup', help: 'Duplicate')
      expect { described_class.counter('dup', help: 'Duplicate') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when accessing unregistered metric' do
      expect { described_class.get('nonexistent') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when incrementing unregistered metric' do
      expect { described_class.increment('missing') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when setting unregistered metric' do
      expect { described_class.set('missing', 1) }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when observing unregistered metric' do
      expect { described_class.observe('missing', 1) }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when snapshotting unregistered metric' do
      expect { described_class.snapshot('missing') }.to raise_error(Philiprehberger::Metric::Error)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent counter increments' do
      described_class.counter('concurrent', help: 'Concurrent')
      threads = Array.new(10) do
        Thread.new do
          100.times { described_class.increment('concurrent') }
        end
      end
      threads.each(&:join)

      counter = described_class.get('concurrent')
      expect(counter.get).to eq(1000)
    end

    it 'handles concurrent gauge updates' do
      described_class.gauge('concurrent_g', help: 'Concurrent gauge')
      gauge = described_class.get('concurrent_g')

      threads = Array.new(10) do
        Thread.new do
          50.times { gauge.increment }
          50.times { gauge.decrement }
        end
      end
      threads.each(&:join)

      expect(gauge.get).to eq(0)
    end

    it 'handles concurrent histogram observations' do
      described_class.histogram('concurrent_h', help: 'Concurrent hist', buckets: [1, 10])
      histogram = described_class.get('concurrent_h')

      threads = Array.new(10) do
        Thread.new do
          100.times { histogram.observe(0.5) }
        end
      end
      threads.each(&:join)

      expect(histogram.get[:count]).to eq(1000)
    end
  end
end
