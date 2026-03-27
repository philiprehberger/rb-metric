# frozen_string_literal: true

module Philiprehberger
  module Metric
    # A monotonically increasing counter metric.
    class Counter
      # @return [String] the metric name
      attr_reader :name

      # @return [String] the help description
      attr_reader :help

      # @param name [String] the metric name
      # @param help [String] the help description
      def initialize(name, help: '')
        @name = name
        @help = help
        @mutex = Mutex.new
        @values = {}
      end

      # Increment the counter.
      #
      # @param amount [Numeric] the amount to increment by (default: 1)
      # @param labels [Hash] optional labels for dimensional metrics
      # @return [void]
      def increment(amount: 1, labels: {})
        key = labels.sort.to_h
        @mutex.synchronize do
          @values[key] = (@values[key] || 0) + amount
        end
      end

      # Get the current value for a set of labels.
      #
      # @param labels [Hash] the label set
      # @return [Numeric] the current counter value
      def get(labels: {})
        key = labels.sort.to_h
        @mutex.synchronize { @values[key] || 0 }
      end

      # Return a snapshot of all values.
      #
      # @return [Hash] labels => value pairs
      def snapshot
        @mutex.synchronize { @values.dup }
      end

      # Reset all values.
      #
      # @return [void]
      def reset
        @mutex.synchronize { @values.clear }
      end

      # @return [String] the metric type name
      def type
        'counter'
      end
    end
  end
end
