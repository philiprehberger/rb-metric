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

    it 'increments by zero without changing the value' do
      described_class.counter('zero_inc', help: 'Zero increment')
      counter = described_class.get('zero_inc')
      counter.increment(amount: 5)
      counter.increment(amount: 0)

      expect(counter.get).to eq(5)
    end

    it 'returns a snapshot with multiple label sets' do
      described_class.counter('multi_label_snap', help: 'Multi labels')
      counter = described_class.get('multi_label_snap')
      counter.increment(labels: { env: 'prod' })
      counter.increment(labels: { env: 'staging' })
      counter.increment(labels: { env: 'prod' })

      snap = counter.snapshot
      expect(snap.size).to eq(2)
      expect(snap[{ env: 'prod' }]).to eq(2)
      expect(snap[{ env: 'staging' }]).to eq(1)
    end

    it 'stores name and help attributes' do
      described_class.counter('attr_check', help: 'Help text here')
      counter = described_class.get('attr_check')

      expect(counter.name).to eq('attr_check')
      expect(counter.help).to eq('Help text here')
    end

    it 'defaults help to empty string' do
      described_class.counter('no_help')
      counter = described_class.get('no_help')

      expect(counter.help).to eq('')
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

    it 'overwrites previous value on set' do
      described_class.gauge('overwrite', help: 'Overwrite test')
      gauge = described_class.get('overwrite')
      gauge.set(100)
      gauge.set(200)

      expect(gauge.get).to eq(200)
    end

    it 'decrements below zero' do
      described_class.gauge('below_zero', help: 'Below zero')
      gauge = described_class.get('below_zero')
      gauge.decrement(amount: 10)

      expect(gauge.get).to eq(-10)
    end

    it 'handles zero value set' do
      described_class.gauge('zero_set', help: 'Zero')
      gauge = described_class.get('zero_set')
      gauge.set(50)
      gauge.set(0)

      expect(gauge.get).to eq(0)
    end

    it 'returns a snapshot with multiple label sets' do
      described_class.gauge('multi_g_snap', help: 'Multi gauge snap')
      gauge = described_class.get('multi_g_snap')
      gauge.set(10, labels: { region: 'us' })
      gauge.set(20, labels: { region: 'eu' })

      snap = gauge.snapshot
      expect(snap.size).to eq(2)
      expect(snap[{ region: 'us' }]).to eq(10)
      expect(snap[{ region: 'eu' }]).to eq(20)
    end

    it 'treats label order consistently for gauges' do
      described_class.gauge('ordered_g', help: 'Ordered gauge')
      gauge = described_class.get('ordered_g')
      gauge.set(42, labels: { z: '1', a: '2' })

      expect(gauge.get(labels: { a: '2', z: '1' })).to eq(42)
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

    it 'counts a value exactly on a bucket boundary' do
      described_class.histogram('boundary', help: 'Boundary', buckets: [1, 5, 10])
      histogram = described_class.get('boundary')
      histogram.observe(5)

      data = histogram.get
      expect(data[:buckets][1]).to eq(0)
      expect(data[:buckets][5]).to eq(1)
      expect(data[:buckets][10]).to eq(1)
    end

    it 'handles observing zero' do
      described_class.histogram('zero_obs', help: 'Zero obs', buckets: [0.1, 1])
      histogram = described_class.get('zero_obs')
      histogram.observe(0)

      data = histogram.get
      expect(data[:count]).to eq(1)
      expect(data[:sum]).to eq(0.0)
      expect(data[:buckets][0.1]).to eq(1)
      expect(data[:buckets][1]).to eq(1)
    end

    it 'handles observing negative values' do
      described_class.histogram('neg_obs', help: 'Negative obs', buckets: [0, 1, 5])
      histogram = described_class.get('neg_obs')
      histogram.observe(-3)

      data = histogram.get
      expect(data[:count]).to eq(1)
      expect(data[:sum]).to eq(-3.0)
      expect(data[:buckets][0]).to eq(1)
      expect(data[:buckets][1]).to eq(1)
      expect(data[:buckets][5]).to eq(1)
    end

    it 'does not count values above all buckets in any bucket' do
      described_class.histogram('above_all', help: 'Above', buckets: [1, 5])
      histogram = described_class.get('above_all')
      histogram.observe(100)

      data = histogram.get
      expect(data[:count]).to eq(1)
      expect(data[:sum]).to eq(100.0)
      expect(data[:buckets][1]).to eq(0)
      expect(data[:buckets][5]).to eq(0)
    end

    it 'accumulates sum correctly across multiple observations' do
      described_class.histogram('sum_acc', help: 'Sum accumulation', buckets: [10])
      histogram = described_class.get('sum_acc')
      histogram.observe(1.5)
      histogram.observe(2.5)
      histogram.observe(3.0)

      data = histogram.get
      expect(data[:sum]).to be_within(0.001).of(7.0)
      expect(data[:count]).to eq(3)
    end

    it 'returns a snapshot with multiple label sets' do
      described_class.histogram('multi_h_snap', help: 'Multi hist snap', buckets: [1])
      histogram = described_class.get('multi_h_snap')
      histogram.observe(0.5, labels: { path: '/' })
      histogram.observe(0.8, labels: { path: '/api' })

      snap = histogram.snapshot
      expect(snap.size).to eq(2)
      expect(snap[{ path: '/' }][:count]).to eq(1)
      expect(snap[{ path: '/api' }][:count]).to eq(1)
    end

    it 'works with a single bucket' do
      described_class.histogram('single_bucket', help: 'Single', buckets: [5])
      histogram = described_class.get('single_bucket')
      histogram.observe(3)
      histogram.observe(7)

      data = histogram.get
      expect(data[:count]).to eq(2)
      expect(data[:buckets][5]).to eq(1)
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

    it 'allows re-registration of metrics after reset' do
      described_class.counter('reusable', help: 'Reusable')
      described_class.increment('reusable')
      described_class.reset

      described_class.counter('reusable', help: 'Reusable again')
      counter = described_class.get('reusable')
      expect(counter.get).to eq(0)
    end
  end

  describe '.default_registry' do
    it 'returns the same registry instance across calls' do
      reg1 = described_class.default_registry
      reg2 = described_class.default_registry

      expect(reg1).to be(reg2)
    end

    it 'returns a new registry after reset' do
      reg_before = described_class.default_registry
      described_class.reset
      reg_after = described_class.default_registry

      expect(reg_before).not_to be(reg_after)
    end
  end

  describe 'error handling' do
    it 'raises on duplicate metric registration' do
      described_class.counter('dup', help: 'Duplicate')
      expect { described_class.counter('dup', help: 'Duplicate') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises on duplicate gauge registration' do
      described_class.gauge('dup_g', help: 'Duplicate gauge')
      expect { described_class.gauge('dup_g', help: 'Duplicate gauge') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises on duplicate histogram registration' do
      described_class.histogram('dup_h', help: 'Duplicate histogram')
      expect { described_class.histogram('dup_h', help: 'Duplicate histogram') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'raises when registering different metric types with the same name' do
      described_class.counter('shared_name', help: 'A counter')
      expect { described_class.gauge('shared_name', help: 'A gauge') }.to raise_error(Philiprehberger::Metric::Error)
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

    it 'includes the metric name in the error message for unregistered metrics' do
      expect { described_class.get('my_missing_metric') }.to raise_error(
        Philiprehberger::Metric::Error, /my_missing_metric/
      )
    end

    it 'includes the metric name in the error message for duplicate registration' do
      described_class.counter('already_exists', help: 'Exists')
      expect { described_class.counter('already_exists', help: 'Exists') }.to raise_error(
        Philiprehberger::Metric::Error, /already_exists/
      )
    end
  end

  describe 'Registry' do
    let(:registry) { Philiprehberger::Metric::Registry.new }

    it 'registers and retrieves a counter directly' do
      counter = registry.counter('direct_c', help: 'Direct counter')
      counter.increment
      expect(registry.get('direct_c').get).to eq(1)
    end

    it 'registers and retrieves a gauge directly' do
      gauge = registry.gauge('direct_g', help: 'Direct gauge')
      gauge.set(99)
      expect(registry.get('direct_g').get).to eq(99)
    end

    it 'registers and retrieves a histogram directly' do
      histogram = registry.histogram('direct_h', help: 'Direct hist', buckets: [1, 5])
      histogram.observe(3)
      expect(registry.get('direct_h').get[:count]).to eq(1)
    end

    it 'increments a counter through the registry' do
      registry.counter('reg_inc', help: 'Registry increment')
      registry.increment('reg_inc', labels: { env: 'test' })
      expect(registry.get('reg_inc').get(labels: { env: 'test' })).to eq(1)
    end

    it 'sets a gauge through the registry' do
      registry.gauge('reg_set', help: 'Registry set')
      registry.set('reg_set', 42, labels: { host: 'local' })
      expect(registry.get('reg_set').get(labels: { host: 'local' })).to eq(42)
    end

    it 'observes a histogram through the registry' do
      registry.histogram('reg_obs', help: 'Registry observe', buckets: [10])
      registry.observe('reg_obs', 5, labels: { path: '/' })
      expect(registry.get('reg_obs').get(labels: { path: '/' })[:count]).to eq(1)
    end

    it 'returns a snapshot through the registry' do
      registry.counter('reg_snap', help: 'Registry snapshot')
      registry.increment('reg_snap')
      snap = registry.snapshot('reg_snap')
      expect(snap[{}]).to eq(1)
    end

    it 'resets all metrics and clears the registry' do
      registry.counter('r1', help: 'R1')
      registry.gauge('r2', help: 'R2')
      registry.increment('r1')
      registry.set('r2', 10)
      registry.reset
      expect { registry.get('r1') }.to raise_error(Philiprehberger::Metric::Error)
      expect { registry.get('r2') }.to raise_error(Philiprehberger::Metric::Error)
    end

    it 'exports an empty registry to Prometheus format' do
      output = registry.to_prometheus
      expect(output).to eq("\n")
    end

    it 'exports an empty registry to JSON' do
      data = JSON.parse(registry.to_json)
      expect(data).to eq({})
    end
  end

  describe 'counter edge cases' do
    it 'handles floating-point increment amounts' do
      described_class.counter('float_inc', help: 'Float increment')
      counter = described_class.get('float_inc')
      counter.increment(amount: 0.5)
      counter.increment(amount: 1.5)
      expect(counter.get).to be_within(0.001).of(2.0)
    end

    it 'handles negative increment amount (no guard)' do
      described_class.counter('neg_inc', help: 'Negative increment')
      counter = described_class.get('neg_inc')
      counter.increment(amount: 10)
      counter.increment(amount: -3)
      expect(counter.get).to eq(7)
    end

    it 'handles very large increment values' do
      described_class.counter('large_inc', help: 'Large increment')
      counter = described_class.get('large_inc')
      counter.increment(amount: 1_000_000_000)
      counter.increment(amount: 1_000_000_000)
      expect(counter.get).to eq(2_000_000_000)
    end

    it 'returns empty snapshot when no increments recorded' do
      described_class.counter('empty_snap', help: 'Empty snapshot')
      counter = described_class.get('empty_snap')
      expect(counter.snapshot).to eq({})
    end

    it 'tracks many distinct label sets independently' do
      described_class.counter('many_labels', help: 'Many labels')
      counter = described_class.get('many_labels')
      20.times { |i| counter.increment(labels: { id: i.to_s }) }
      expect(counter.snapshot.size).to eq(20)
    end
  end

  describe 'gauge edge cases' do
    it 'increments gauge with labels' do
      described_class.gauge('g_inc_labels', help: 'Gauge inc labels')
      gauge = described_class.get('g_inc_labels')
      gauge.increment(amount: 5, labels: { host: 'a' })
      gauge.increment(amount: 3, labels: { host: 'a' })
      expect(gauge.get(labels: { host: 'a' })).to eq(8)
    end

    it 'decrements gauge with labels' do
      described_class.gauge('g_dec_labels', help: 'Gauge dec labels')
      gauge = described_class.get('g_dec_labels')
      gauge.set(100, labels: { region: 'us' })
      gauge.decrement(amount: 30, labels: { region: 'us' })
      expect(gauge.get(labels: { region: 'us' })).to eq(70)
    end

    it 'handles floating-point set values' do
      described_class.gauge('g_float', help: 'Float gauge')
      gauge = described_class.get('g_float')
      gauge.set(3.14159)
      expect(gauge.get).to be_within(0.00001).of(3.14159)
    end

    it 'returns empty snapshot for unset gauge' do
      described_class.gauge('g_empty_snap', help: 'Empty gauge snap')
      gauge = described_class.get('g_empty_snap')
      expect(gauge.snapshot).to eq({})
    end

    it 'stores name and help attributes' do
      described_class.gauge('g_attrs', help: 'Gauge attributes')
      gauge = described_class.get('g_attrs')
      expect(gauge.name).to eq('g_attrs')
      expect(gauge.help).to eq('Gauge attributes')
    end

    it 'defaults help to empty string' do
      described_class.gauge('g_no_help')
      gauge = described_class.get('g_no_help')
      expect(gauge.help).to eq('')
    end
  end

  describe 'histogram edge cases' do
    it 'handles multiple observations on the same label set' do
      described_class.histogram('h_multi', help: 'Multi obs', buckets: [1, 5, 10])
      histogram = described_class.get('h_multi')
      histogram.observe(0.5, labels: { path: '/' })
      histogram.observe(3.0, labels: { path: '/' })
      histogram.observe(7.0, labels: { path: '/' })

      data = histogram.get(labels: { path: '/' })
      expect(data[:count]).to eq(3)
      expect(data[:sum]).to be_within(0.001).of(10.5)
      expect(data[:buckets][1]).to eq(1)
      expect(data[:buckets][5]).to eq(2)
      expect(data[:buckets][10]).to eq(3)
    end

    it 'stores name and help attributes' do
      described_class.histogram('h_attrs', help: 'Histogram attributes')
      histogram = described_class.get('h_attrs')
      expect(histogram.name).to eq('h_attrs')
      expect(histogram.help).to eq('Histogram attributes')
    end

    it 'defaults help to empty string' do
      described_class.histogram('h_no_help')
      histogram = described_class.get('h_no_help')
      expect(histogram.help).to eq('')
    end

    it 'treats label order consistently for histograms' do
      described_class.histogram('h_ordered', help: 'Ordered hist', buckets: [10])
      histogram = described_class.get('h_ordered')
      histogram.observe(5, labels: { z: '1', a: '2' })

      data = histogram.get(labels: { a: '2', z: '1' })
      expect(data[:count]).to eq(1)
    end

    it 'handles very large observed values' do
      described_class.histogram('h_large', help: 'Large obs', buckets: [100])
      histogram = described_class.get('h_large')
      histogram.observe(999_999_999)

      data = histogram.get
      expect(data[:sum]).to eq(999_999_999)
      expect(data[:buckets][100]).to eq(0)
    end

    it 'snapshot returns deep copy that does not mutate internal state' do
      described_class.histogram('h_deep', help: 'Deep copy', buckets: [10])
      histogram = described_class.get('h_deep')
      histogram.observe(5)

      snap = histogram.snapshot
      snap[{}][:count] = 999

      expect(histogram.get[:count]).to eq(1)
    end
  end

  describe '.to_prometheus advanced' do
    it 'exports histogram with labels in Prometheus format' do
      described_class.histogram('prom_h_labels', help: 'Prometheus hist labels', buckets: [1, 5])
      described_class.observe('prom_h_labels', 0.5, labels: { method: 'GET' })

      output = described_class.to_prometheus
      expect(output).to include('prom_h_labels_bucket{method="GET",le="1"} 1')
      expect(output).to include('prom_h_labels_bucket{method="GET",le="5"} 1')
      expect(output).to include('prom_h_labels_bucket{method="GET",le="+Inf"} 1')
      expect(output).to include('prom_h_labels_sum{method="GET"} 0.5')
      expect(output).to include('prom_h_labels_count{method="GET"} 1')
    end

    it 'exports gauge without labels in Prometheus format' do
      described_class.gauge('prom_g_nolabel', help: 'Gauge no labels')
      described_class.set('prom_g_nolabel', 42)

      output = described_class.to_prometheus
      expect(output).to include('prom_g_nolabel{} 42')
    end

    it 'exports multiple metrics in order' do
      described_class.counter('prom_a', help: 'First')
      described_class.gauge('prom_b', help: 'Second')
      described_class.increment('prom_a')
      described_class.set('prom_b', 10)

      output = described_class.to_prometheus
      expect(output).to include('# TYPE prom_a counter')
      expect(output).to include('# TYPE prom_b gauge')
    end

    it 'exports histogram without labels with empty label string' do
      described_class.histogram('prom_h_nolabel', help: 'Hist no labels', buckets: [1])
      described_class.observe('prom_h_nolabel', 0.5)

      output = described_class.to_prometheus
      expect(output).to include('prom_h_nolabel_bucket{le="1"} 1')
      expect(output).to include('prom_h_nolabel_bucket{le="+Inf"} 1')
      expect(output).to include('prom_h_nolabel_sum{} 0.5')
      expect(output).to include('prom_h_nolabel_count{} 1')
    end
  end

  describe '.to_json advanced' do
    it 'exports gauge values in JSON' do
      described_class.gauge('json_g', help: 'JSON gauge')
      described_class.set('json_g', 55)

      data = JSON.parse(described_class.to_json)
      expect(data['json_g']['type']).to eq('gauge')
      expect(data['json_g']['help']).to eq('JSON gauge')
    end

    it 'exports histogram values in JSON' do
      described_class.histogram('json_h', help: 'JSON histogram', buckets: [1])
      described_class.observe('json_h', 0.5)

      data = JSON.parse(described_class.to_json)
      expect(data['json_h']['type']).to eq('histogram')
      expect(data['json_h']['values']).to be_a(Hash)
    end

    it 'exports empty metric values in JSON' do
      described_class.counter('json_empty', help: 'Empty counter')

      data = JSON.parse(described_class.to_json)
      expect(data['json_empty']['values']).to eq({})
    end
  end

  describe 'module convenience methods' do
    it 'registers a gauge with help via module method' do
      gauge = described_class.gauge('conv_g', help: 'Convenience gauge')
      expect(gauge).to be_a(Philiprehberger::Metric::Gauge)
      expect(gauge.help).to eq('Convenience gauge')
    end

    it 'registers a histogram with custom buckets via module method' do
      histogram = described_class.histogram('conv_h', help: 'Convenience hist', buckets: [1, 2, 3])
      expect(histogram).to be_a(Philiprehberger::Metric::Histogram)
      expect(histogram.buckets).to eq([1, 2, 3])
    end

    it 'registers a counter via module method and returns Counter instance' do
      counter = described_class.counter('conv_c', help: 'Convenience counter')
      expect(counter).to be_a(Philiprehberger::Metric::Counter)
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
