# frozen_string_literal: true

module Philiprehberger
  module Metric
    # A histogram metric that tracks value distributions across configurable buckets.
    class Histogram
      # Default histogram buckets matching Prometheus defaults.
      DEFAULT_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze

      # @return [String] the metric name
      attr_reader :name

      # @return [String] the help description
      attr_reader :help

      # @return [Array<Numeric>] the bucket boundaries
      attr_reader :buckets

      # @param name [String] the metric name
      # @param help [String] the help description
      # @param buckets [Array<Numeric>] bucket boundaries (default: Prometheus defaults)
      def initialize(name, help: '', buckets: DEFAULT_BUCKETS)
        @name = name
        @help = help
        @buckets = buckets.sort.freeze
        @mutex = Mutex.new
        @observations = {}
      end

      # Observe a value.
      #
      # @param value [Numeric] the observed value
      # @param labels [Hash] optional labels
      # @return [void]
      def observe(value, labels: {})
        key = labels.sort.to_h
        @mutex.synchronize do
          @observations[key] ||= { buckets: Hash.new(0), sum: 0.0, count: 0 }
          entry = @observations[key]
          entry[:sum] += value
          entry[:count] += 1
          @buckets.each do |bound|
            entry[:buckets][bound] += 1 if value <= bound
          end
        end
      end

      # Get a snapshot for a specific label set.
      #
      # @param labels [Hash] the label set
      # @return [Hash] with :buckets, :sum, :count keys
      def get(labels: {})
        key = labels.sort.to_h
        @mutex.synchronize do
          entry = @observations[key]
          return { buckets: {}, sum: 0.0, count: 0 } unless entry

          {
            buckets: entry[:buckets].dup,
            sum: entry[:sum],
            count: entry[:count]
          }
        end
      end

      # Return a snapshot of all observations.
      #
      # @return [Hash] labels => observation data
      def snapshot
        @mutex.synchronize do
          @observations.transform_values do |entry|
            {
              buckets: entry[:buckets].dup,
              sum: entry[:sum],
              count: entry[:count]
            }
          end
        end
      end

      # Reset all observations.
      #
      # @return [void]
      def reset
        @mutex.synchronize { @observations.clear }
      end

      # @return [String] the metric type name
      def type
        'histogram'
      end
    end
  end
end
