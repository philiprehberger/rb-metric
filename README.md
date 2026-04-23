# philiprehberger-metric

[![Tests](https://github.com/philiprehberger/rb-metric/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-metric/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-metric.svg)](https://rubygems.org/gems/philiprehberger-metric)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-metric)](https://github.com/philiprehberger/rb-metric/commits/main)

In-process application metrics with counters, gauges, histograms, and summaries

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
gauge.add(2.5)   # relative adjustment; negative values subtract
gauge.add(-1)
```

### Histograms

```ruby
Philiprehberger::Metric.histogram("request_duration", help: "Request duration", buckets: [0.1, 0.5, 1, 5, 10])
Philiprehberger::Metric.observe("request_duration", 0.342)

data = Philiprehberger::Metric.snapshot("request_duration")
```

### Summaries

```ruby
Philiprehberger::Metric.summary("response_size", help: "Response sizes", quantiles: [0.5, 0.9, 0.99])
Philiprehberger::Metric.observe("response_size", 1024)
Philiprehberger::Metric.observe("response_size", 2048)

summary = Philiprehberger::Metric.get("response_size")
summary.get # => { count: 2, sum: 3072.0, 0.5 => 1024.0, 0.9 => 2048.0, 0.99 => 2048.0 }
```

### Timing Helper

```ruby
registry = Philiprehberger::Metric::Registry.new
registry.histogram("operation_duration", help: "Operation duration")

result = registry.time("operation_duration", labels: { op: "compute" }) do
  expensive_operation
end
```

### Timer

For flows where a block is awkward (for example, when start and stop live in different methods or callbacks), use `Timer` for a scoped manual-stop alternative.

```ruby
Philiprehberger::Metric.histogram("job_duration", help: "Job duration")

timer = Philiprehberger::Metric::Timer.new("job_duration")
do_work
timer.stop(labels: { job: "import" })
# => elapsed seconds (Float); stop is idempotent — subsequent calls return the cached value
```

Pass a specific registry with `Timer.new("job_duration", registry: my_registry)`. `#elapsed` reads the current elapsed seconds without stopping, and `#reset` discards a running timer (after reset, `#stop` raises).

### Bucket Helpers

```ruby
linear = Philiprehberger::Metric::Histogram.linear_buckets(start: 0.1, width: 0.1, count: 5)
# => [0.1, 0.2, 0.3, 0.4, 0.5]

exp = Philiprehberger::Metric::Histogram.exponential_buckets(start: 1, factor: 2, count: 4)
# => [1, 2, 4, 8]

Philiprehberger::Metric.histogram("payload_bytes", help: "Payload size", buckets: exp)
```

### Introspection

```ruby
Philiprehberger::Metric.counter("requests", help: "Requests")
Philiprehberger::Metric.registered?("requests") # => true
Philiprehberger::Metric.names                    # => ["requests"]
Philiprehberger::Metric.unregister("requests")
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

### StatsD Export

```ruby
output = Philiprehberger::Metric.to_statsd
# => "http_requests_total,method=GET:1|c"
```

## API

### `Metric` (Module)

| Method | Description |
|--------|-------------|
| `.counter(name, help:)` | Register a counter metric |
| `.gauge(name, help:)` | Register a gauge metric |
| `.histogram(name, help:, buckets:)` | Register a histogram metric |
| `.summary(name, help:, quantiles:)` | Register a summary metric |
| `.increment(name, labels:)` | Increment a counter |
| `.set(name, value, labels:)` | Set a gauge value |
| `.observe(name, value, labels:)` | Observe a histogram or summary value |
| `.time(name, labels:) { block }` | Measure block duration as histogram observation |
| `.get(name)` | Get a registered metric by name |
| `.snapshot(name)` | Get a snapshot of a metric's values |
| `.to_prometheus` | Export all metrics in Prometheus text format |
| `.to_json` | Export all metrics as JSON |
| `.to_statsd` | Export all metrics in StatsD line protocol |
| `.names` | List names of all registered metrics |
| `.registered?(name)` | Check whether a metric is registered |
| `.unregister(name, strict:)` | Remove a metric; `strict: true` raises if the metric is missing |
| `.reset` | Reset and clear all registered metrics |

### `Counter`

Counters are monotonic: `#increment` rejects negative amounts and raises `Philiprehberger::Metric::Error`. Use a `Gauge` for values that can decrease.

| Method | Description |
|--------|-------------|
| `#increment(amount:, labels:)` | Increment the counter (raises on negative `amount`) |
| `#get(labels:)` | Get the current value |

### `Gauge`

| Method | Description |
|--------|-------------|
| `#set(value, labels:)` | Set the gauge value |
| `#increment(amount:, labels:)` | Increment the gauge |
| `#decrement(amount:, labels:)` | Decrement the gauge |
| `#add(value, labels:)` | Atomically add a value to the gauge (negative subtracts) |
| `#get(labels:)` | Get the current value |

### `Histogram`

| Method | Description |
|--------|-------------|
| `.linear_buckets(start:, width:, count:)` | Build a linear sequence of bucket boundaries |
| `.exponential_buckets(start:, factor:, count:)` | Build an exponential sequence of bucket boundaries |
| `#observe(value, labels:)` | Observe a value |
| `#get(labels:)` | Get bucket counts, sum, and count |

### `Summary`

| Method | Description |
|--------|-------------|
| `#observe(value, labels:)` | Observe a value |
| `#get(labels:)` | Get quantile values, sum, and count |

### `Timer`

| Method | Description |
|--------|-------------|
| `.new(histogram_name, registry:)` | Start a new timer bound to a registered histogram |
| `#stop(labels:)` | Record the elapsed seconds as a histogram observation; idempotent (cached return) |
| `#elapsed` | Return the current elapsed seconds without stopping |
| `#reset` | Discard the running timer; subsequent `#stop` raises `Error` |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-metric)

🐛 [Report issues](https://github.com/philiprehberger/rb-metric/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-metric/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
