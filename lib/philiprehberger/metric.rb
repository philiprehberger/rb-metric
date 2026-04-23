# frozen_string_literal: true

module Philiprehberger
  module Metric
    class Error < StandardError; end

    @default_registry = nil
    @registry_mutex = Mutex.new

    # Return the default global registry.
    #
    # @return [Registry]
    def self.default_registry
      @registry_mutex.synchronize do
        @default_registry ||= Registry.new
      end
    end

    # Register a counter metric on the default registry.
    #
    # @param name [String] the metric name
    # @param help [String] the help description
    # @return [Counter]
    def self.counter(name, help: '')
      default_registry.counter(name, help: help)
    end

    # Register a gauge metric on the default registry.
    #
    # @param name [String] the metric name
    # @param help [String] the help description
    # @return [Gauge]
    def self.gauge(name, help: '')
      default_registry.gauge(name, help: help)
    end

    # Register a histogram metric on the default registry.
    #
    # @param name [String] the metric name
    # @param help [String] the help description
    # @param buckets [Array<Numeric>] bucket boundaries
    # @return [Histogram]
    def self.histogram(name, help: '', buckets: Histogram::DEFAULT_BUCKETS)
      default_registry.histogram(name, help: help, buckets: buckets)
    end

    # Register a summary metric on the default registry.
    #
    # @param name [String] the metric name
    # @param help [String] the help description
    # @param quantiles [Array<Float>] quantiles to compute
    # @return [Summary]
    def self.summary(name, help: '', quantiles: Summary::DEFAULT_QUANTILES)
      default_registry.summary(name, help: help, quantiles: quantiles)
    end

    # Increment a counter on the default registry.
    #
    # @param name [String] the metric name
    # @param labels [Hash] optional labels
    # @return [void]
    def self.increment(name, labels: {})
      default_registry.increment(name, labels: labels)
    end

    # Set a gauge value on the default registry.
    #
    # @param name [String] the metric name
    # @param value [Numeric] the value to set
    # @param labels [Hash] optional labels
    # @return [void]
    def self.set(name, value, labels: {})
      default_registry.set(name, value, labels: labels)
    end

    # Observe a histogram value on the default registry.
    #
    # @param name [String] the metric name
    # @param value [Numeric] the observed value
    # @param labels [Hash] optional labels
    # @return [void]
    def self.observe(name, value, labels: {})
      default_registry.observe(name, value, labels: labels)
    end

    # Get a registered metric from the default registry.
    #
    # @param name [String] the metric name
    # @return [Counter, Gauge, Histogram]
    def self.get(name)
      default_registry.get(name)
    end

    # Get a snapshot of a metric from the default registry.
    #
    # @param name [String] the metric name
    # @return [Hash]
    def self.snapshot(name)
      default_registry.snapshot(name)
    end

    # Measure block execution time and record as a histogram observation.
    #
    # @param name [String] the histogram metric name
    # @param labels [Hash] optional labels
    # @return [Object] the block's return value
    def self.time(name, labels: {}, &block)
      default_registry.time(name, labels: labels, &block)
    end

    # Export all metrics in Prometheus text exposition format.
    #
    # @return [String]
    def self.to_prometheus
      default_registry.to_prometheus
    end

    # Export all metrics as JSON.
    #
    # @return [String]
    def self.to_json(*args)
      default_registry.to_json(*args)
    end

    # Export all metrics in StatsD line protocol format.
    #
    # @return [String]
    def self.to_statsd
      default_registry.to_statsd
    end

    # List the names of all metrics on the default registry.
    #
    # @return [Array<String>]
    def self.names
      default_registry.names
    end

    # Check whether a metric is registered on the default registry.
    #
    # @param name [String] the metric name
    # @return [Boolean]
    def self.registered?(name)
      default_registry.registered?(name)
    end

    # Unregister a metric from the default registry.
    #
    # @param name [String] the metric name
    # @param strict [Boolean] when +true+, raise {Error} if the metric is not registered (default +false+)
    # @return [Counter, Gauge, Histogram, Summary, nil]
    def self.unregister(name, strict: false)
      default_registry.unregister(name, strict: strict)
    end

    # Reset the default registry.
    #
    # @return [void]
    def self.reset
      @registry_mutex.synchronize do
        @default_registry&.reset
        @default_registry = nil
      end
    end
  end
end

require_relative 'metric/version'
require_relative 'metric/counter'
require_relative 'metric/gauge'
require_relative 'metric/histogram'
require_relative 'metric/summary'
require_relative 'metric/registry'
require_relative 'metric/timer'
