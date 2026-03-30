# frozen_string_literal: true

module Philiprehberger
  module Metric
    # A summary metric that tracks value distributions and computes quantile estimates.
    class Summary
      # Default quantiles for summary metrics.
      DEFAULT_QUANTILES = [0.5, 0.9, 0.99].freeze

      # @return [String] the metric name
      attr_reader :name

      # @return [String] the help description
      attr_reader :help

      # @return [Array<Float>] the quantiles to compute
      attr_reader :quantiles

      # @param name [String] the metric name
      # @param help [String] the help description
      # @param quantiles [Array<Float>] quantiles to compute (default: [0.5, 0.9, 0.99])
      def initialize(name, help: '', quantiles: DEFAULT_QUANTILES)
        @name = name
        @help = help
        @quantiles = quantiles.sort.freeze
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
          @observations[key] ||= { values: [], sum: 0.0, count: 0 }
          entry = @observations[key]
          entry[:values] << value
          entry[:sum] += value
          entry[:count] += 1
        end
      end

      # Get a snapshot for a specific label set.
      #
      # @param labels [Hash] the label set
      # @return [Hash] with :count, :sum, and each quantile value
      def get(labels: {})
        key = labels.sort.to_h
        @mutex.synchronize do
          entry = @observations[key]
          return build_empty_result unless entry

          sorted = entry[:values].sort
          result = { count: entry[:count], sum: entry[:sum] }
          @quantiles.each do |q|
            result[q] = compute_quantile(sorted, q)
          end
          result
        end
      end

      # Return a snapshot of all observations.
      #
      # @return [Hash] labels => observation data
      def snapshot
        @mutex.synchronize do
          @observations.transform_values do |entry|
            sorted = entry[:values].sort
            result = { count: entry[:count], sum: entry[:sum] }
            @quantiles.each do |q|
              result[q] = compute_quantile(sorted, q)
            end
            result
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
        'summary'
      end

      private

      def build_empty_result
        result = { count: 0, sum: 0.0 }
        @quantiles.each { |q| result[q] = 0.0 }
        result
      end

      def compute_quantile(sorted, quantile)
        return 0.0 if sorted.empty?

        index = (quantile * (sorted.length - 1)).round
        sorted[index].to_f
      end
    end
  end
end
