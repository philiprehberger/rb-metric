# frozen_string_literal: true

require 'json'

module Philiprehberger
  module Metric
    # Global metric registry that stores and manages all metrics.
    class Registry
      def initialize
        @mutex = Mutex.new
        @metrics = {}
      end

      # Register a counter metric.
      #
      # @param name [String] the metric name
      # @param help [String] the help description
      # @return [Counter]
      def counter(name, help: '')
        @mutex.synchronize do
          raise Error, "Metric '#{name}' already registered" if @metrics.key?(name)

          @metrics[name] = Counter.new(name, help: help)
        end
      end

      # Register a gauge metric.
      #
      # @param name [String] the metric name
      # @param help [String] the help description
      # @return [Gauge]
      def gauge(name, help: '')
        @mutex.synchronize do
          raise Error, "Metric '#{name}' already registered" if @metrics.key?(name)

          @metrics[name] = Gauge.new(name, help: help)
        end
      end

      # Register a histogram metric.
      #
      # @param name [String] the metric name
      # @param help [String] the help description
      # @param buckets [Array<Numeric>] bucket boundaries
      # @return [Histogram]
      def histogram(name, help: '', buckets: Histogram::DEFAULT_BUCKETS)
        @mutex.synchronize do
          raise Error, "Metric '#{name}' already registered" if @metrics.key?(name)

          @metrics[name] = Histogram.new(name, help: help, buckets: buckets)
        end
      end

      # Register a summary metric.
      #
      # @param name [String] the metric name
      # @param help [String] the help description
      # @param quantiles [Array<Float>] quantiles to compute
      # @return [Summary]
      def summary(name, help: '', quantiles: Summary::DEFAULT_QUANTILES)
        @mutex.synchronize do
          raise Error, "Metric '#{name}' already registered" if @metrics.key?(name)

          @metrics[name] = Summary.new(name, help: help, quantiles: quantiles)
        end
      end

      # Increment a counter metric.
      #
      # @param name [String] the metric name
      # @param labels [Hash] optional labels
      # @return [void]
      def increment(name, labels: {})
        metric = fetch(name)
        metric.increment(labels: labels)
      end

      # Set a gauge metric value.
      #
      # @param name [String] the metric name
      # @param value [Numeric] the value to set
      # @param labels [Hash] optional labels
      # @return [void]
      def set(name, value, labels: {})
        metric = fetch(name)
        metric.set(value, labels: labels)
      end

      # Observe a histogram or summary value.
      #
      # @param name [String] the metric name
      # @param value [Numeric] the observed value
      # @param labels [Hash] optional labels
      # @return [void]
      def observe(name, value, labels: {})
        metric = fetch(name)
        metric.observe(value, labels: labels)
      end

      # Measure block execution time and record as a histogram observation.
      #
      # @param name [String] the histogram metric name (must already be registered)
      # @param labels [Hash] optional labels
      # @return [Object] the block's return value
      def time(name, labels: {})
        metric = fetch(name)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        metric.observe(duration, labels: labels)
        result
      end

      # Get a registered metric by name.
      #
      # @param name [String] the metric name
      # @return [Counter, Gauge, Histogram]
      # @raise [Error] if the metric is not registered
      def get(name)
        fetch(name)
      end

      # Get a snapshot of a specific metric.
      #
      # @param name [String] the metric name
      # @return [Hash]
      def snapshot(name)
        fetch(name).snapshot
      end

      # Export all metrics in Prometheus text exposition format.
      #
      # @return [String]
      def to_prometheus
        lines = []
        @mutex.synchronize { @metrics.dup }.each_value do |metric|
          lines << "# HELP #{metric.name} #{metric.help}"
          lines << "# TYPE #{metric.name} #{metric.type}"
          format_prometheus_metric(lines, metric)
        end
        "#{lines.join("\n")}\n"
      end

      # Export all metrics as JSON.
      #
      # @return [String]
      def to_json(*_args)
        data = {}
        @mutex.synchronize { @metrics.dup }.each do |name, metric|
          data[name] = {
            type: metric.type,
            help: metric.help,
            values: metric.snapshot
          }
        end
        JSON.generate(data)
      end

      # Export all metrics in StatsD line protocol format.
      #
      # @return [String]
      def to_statsd
        lines = []
        @mutex.synchronize { @metrics.dup }.each_value do |metric|
          format_statsd_metric(lines, metric)
        end
        lines.join("\n")
      end

      # Reset all metrics.
      #
      # @return [void]
      def reset
        @mutex.synchronize do
          @metrics.each_value(&:reset)
          @metrics.clear
        end
      end

      private

      def fetch(name)
        @mutex.synchronize do
          raise Error, "Metric '#{name}' not registered" unless @metrics.key?(name)

          @metrics[name]
        end
      end

      def format_prometheus_metric(lines, metric)
        metric.snapshot.each do |labels, value|
          label_str = format_labels(labels)
          case metric
          when Histogram
            metric.buckets.each do |bound|
              count = value[:buckets][bound] || 0
              lines << "#{metric.name}_bucket{#{label_str}#{',' unless label_str.empty?}le=\"#{bound}\"} #{count}"
            end
            lines << "#{metric.name}_bucket{#{label_str}#{',' unless label_str.empty?}le=\"+Inf\"} #{value[:count]}"
            lines << "#{metric.name}_sum{#{label_str}} #{value[:sum]}"
            lines << "#{metric.name}_count{#{label_str}} #{value[:count]}"
          when Summary
            metric.quantiles.each do |q|
              lines << "#{metric.name}{#{label_str}#{',' unless label_str.empty?}quantile=\"#{q}\"} #{value[q]}"
            end
            lines << "#{metric.name}_sum{#{label_str}} #{value[:sum]}"
            lines << "#{metric.name}_count{#{label_str}} #{value[:count]}"
          else
            lines << "#{metric.name}{#{label_str}} #{value}"
          end
        end
      end

      def format_statsd_metric(lines, metric)
        metric.snapshot.each do |labels, value|
          tags = format_statsd_tags(labels)
          name_with_tags = tags.empty? ? metric.name : "#{metric.name},#{tags}"
          case metric
          when Counter
            lines << "#{name_with_tags}:#{value}|c"
          when Gauge
            lines << "#{name_with_tags}:#{value}|g"
          when Histogram
            lines << "#{name_with_tags}:#{value[:sum]}|ms"
            lines << "#{name_with_tags}.count:#{value[:count]}|c"
          when Summary
            metric.quantiles.each do |q|
              lines << "#{name_with_tags}.p#{(q * 100).to_i}:#{value[q]}|g"
            end
            lines << "#{name_with_tags}.count:#{value[:count]}|c"
            lines << "#{name_with_tags}.sum:#{value[:sum]}|g"
          end
        end
      end

      def format_labels(labels)
        return '' if labels.empty?

        labels.map { |k, v| "#{k}=\"#{v}\"" }.join(',')
      end

      def format_statsd_tags(labels)
        return '' if labels.empty?

        labels.map { |k, v| "#{k}=#{v}" }.join(',')
      end
    end
  end
end
