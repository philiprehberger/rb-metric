# frozen_string_literal: true

module Philiprehberger
  module Metric
    # A scoped timer that measures elapsed time between construction and an explicit stop.
    #
    # Provides an alternative to the block-based {Registry#time} helper for flows where
    # a block is awkward (for example, when the start and stop occur in different methods
    # or across callback boundaries).
    #
    # @example Timing a flow with manual stop
    #   Philiprehberger::Metric.histogram('job_duration', help: 'Job duration')
    #   timer = Philiprehberger::Metric::Timer.new('job_duration')
    #   do_work
    #   timer.stop(labels: { job: 'import' })
    class Timer
      # Create a new timer and capture the start time.
      #
      # @param histogram_name [String] the name of a histogram metric registered on +registry+
      # @param registry [Registry] the registry that owns the target histogram (defaults to the global registry)
      def initialize(histogram_name, registry: Philiprehberger::Metric.default_registry)
        @histogram_name = histogram_name
        @registry = registry
        @start = monotonic_now
        @stopped_at = nil
        @recorded_elapsed = nil
        @reset = false
      end

      # Stop the timer and record the elapsed seconds into the target histogram.
      #
      # Idempotent: subsequent calls return the cached elapsed value from the first stop
      # without recording an additional observation. After an explicit {#reset}, calling
      # +#stop+ raises {Error} — reset leaves the timer in a state that cannot be stopped
      # again without re-constructing the timer.
      #
      # @param labels [Hash] optional labels to attach to the histogram observation
      # @return [Float] the elapsed seconds recorded (or cached from the first call)
      # @raise [Error] if called after {#reset}
      def stop(labels: {})
        raise Error, 'Timer has been reset; cannot stop a reset timer' if @reset
        return @recorded_elapsed if @stopped_at

        elapsed = monotonic_now - @start
        @registry.observe(@histogram_name, elapsed, labels: labels)
        @stopped_at = monotonic_now
        @recorded_elapsed = elapsed
      end

      # Return the elapsed seconds since construction without stopping the timer.
      #
      # If the timer has already been stopped, returns the elapsed value captured at
      # stop time.
      #
      # @return [Float] elapsed seconds
      def elapsed
        return @recorded_elapsed if @stopped_at

        monotonic_now - @start
      end

      # Reset the timer, clearing the stopped state.
      #
      # After reset, {#stop} will raise — the timer must be re-constructed for a
      # fresh measurement. Use reset primarily as a way to discard a running timer
      # without recording an observation.
      #
      # @return [void]
      def reset
        @start = monotonic_now
        @stopped_at = nil
        @recorded_elapsed = nil
        @reset = true
      end

      private

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
