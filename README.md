# philiprehberger-metric

[![Tests](https://github.com/philiprehberger/rb-metric/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-metric/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-metric.svg)](https://rubygems.org/gems/philiprehberger-metric)
[![License](https://img.shields.io/github/license/philiprehberger/rb-metric)](LICENSE)

In-process application metrics with counters, gauges, and histograms

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-metric"
```

Or install directly:

```bash
gem install philiprehberger-metric
```

## Usage

```ruby
require "philiprehberger/metric"

Philiprehberger::Metric.counter("http_requests_total", help: "Total HTTP requests")
Philiprehberger::Metric.increment("http_requests_total", labels: { method: "GET" })

counter = Philiprehberger::Metric.get("http_requests_total")
counter.get(labels: { method: "GET" }) # => 1
```

### Counters

```ruby
Philiprehberger::Metric.counter("events_total", help: "Total events processed")
Philiprehberger::Metric.increment("events_total")
Philiprehberger::Metric.increment("events_total", labels: { type: "click" })
```

### Gauges

```ruby
Philiprehberger::Metric.gauge("temperature", help: "Current temperature")
Philiprehberger::Metric.set("temperature", 72.5)

gauge = Philiprehberger::Metric.get("temperature")
gauge.increment
gauge.decrement
```

### Histograms

```ruby
Philiprehberger::Metric.histogram("request_duration", help: "Request duration", buckets: [0.1, 0.5, 1, 5, 10])
Philiprehberger::Metric.observe("request_duration", 0.342)

data = Philiprehberger::Metric.snapshot("request_duration")
```

### Prometheus Export

```ruby
output = Philiprehberger::Metric.to_prometheus
# => "# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\n..."
```

### JSON Export

```ruby
json = Philiprehberger::Metric.to_json
# => '{"http_requests_total":{"type":"counter","help":"Total HTTP requests","values":{...}}}'
```

## API

### `Metric` (Module)

| Method | Description |
|--------|-------------|
| `.counter(name, help:)` | Register a counter metric |
| `.gauge(name, help:)` | Register a gauge metric |
| `.histogram(name, help:, buckets:)` | Register a histogram metric |
| `.increment(name, labels:)` | Increment a counter |
| `.set(name, value, labels:)` | Set a gauge value |
| `.observe(name, value, labels:)` | Observe a histogram value |
| `.get(name)` | Get a registered metric by name |
| `.snapshot(name)` | Get a snapshot of a metric's values |
| `.to_prometheus` | Export all metrics in Prometheus text format |
| `.to_json` | Export all metrics as JSON |
| `.reset` | Reset and clear all registered metrics |

### `Counter`

| Method | Description |
|--------|-------------|
| `#increment(amount:, labels:)` | Increment the counter |
| `#get(labels:)` | Get the current value |

### `Gauge`

| Method | Description |
|--------|-------------|
| `#set(value, labels:)` | Set the gauge value |
| `#increment(amount:, labels:)` | Increment the gauge |
| `#decrement(amount:, labels:)` | Decrement the gauge |
| `#get(labels:)` | Get the current value |

### `Histogram`

| Method | Description |
|--------|-------------|
| `#observe(value, labels:)` | Observe a value |
| `#get(labels:)` | Get bucket counts, sum, and count |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
