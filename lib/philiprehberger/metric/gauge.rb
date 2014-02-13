# frozen_string_literal: true

module Philiprehberger
  module Metric
    # A gauge metric that can go up and down.
    class Gauge
      # @return [String] the metric name
      attr_reader :name

      # @return [String] the help description
      attr_reader :help

      # @param name [String] the metric name
      # @param help [String] the help description
      def initialize(name, help: "")
        @name = name
        @help = help
        @mutex = Mutex.new
        @values = {}
      end

      # Set the gauge to a specific value.
      #
      # @param value [Numeric] the value to set
      # @param labels [Hash] optional labels
      # @return [void]
      def set(value, labels: {})
        key = labels.sort.to_h
        @mutex.synchronize { @values[key] = value }
      end

      # Increment the gauge.
      #
      # @param amount [Numeric] the amount to increment by (default: 1)
      # @param labels [Hash] optional labels
      # @return [void]
      def increment(amount: 1, labels: {})
        key = labels.sort.to_h
        @mutex.synchronize do
          @values[key] = (@values[key] || 0) + amount
        end
      end

      # Decrement the gauge.
      #
      # @param amount [Numeric] the amount to decrement by (default: 1)
      # @param labels [Hash] optional labels
      # @return [void]
      def decrement(amount: 1, labels: {})
        increment(amount: -amount, labels: labels)
      end

      # Get the current value for a set of labels.
      #
      # @param labels [Hash] the label set
      # @return [Numeric] the current gauge value
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
        "gauge"
      end
    end
  end
end
