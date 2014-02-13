# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Philiprehberger::Metric do
  before { described_class.reset }

  it "has a version number" do
    expect(Philiprehberger::Metric::VERSION).not_to be_nil
  end

  describe "counter" do
    it "registers and increments a counter" do
      described_class.counter("http_requests_total", help: "Total HTTP requests")
      described_class.increment("http_requests_total")
      described_class.increment("http_requests_total")

      counter = described_class.get("http_requests_total")
      expect(counter.get).to eq(2)
    end

    it "supports labels" do
      described_class.counter("requests", help: "Requests")
      described_class.increment("requests", labels: { method: "GET" })
      described_class.increment("requests", labels: { method: "POST" })
      described_class.increment("requests", labels: { method: "GET" })

      counter = described_class.get("requests")
      expect(counter.get(labels: { method: "GET" })).to eq(2)
      expect(counter.get(labels: { method: "POST" })).to eq(1)
    end
  end

  describe "gauge" do
    it "registers and sets a gauge" do
      described_class.gauge("temperature", help: "Current temperature")
      described_class.set("temperature", 72.5)

      gauge = described_class.get("temperature")
      expect(gauge.get).to eq(72.5)
    end

    it "supports increment and decrement" do
      described_class.gauge("active_connections", help: "Active connections")
      gauge = described_class.get("active_connections")
      gauge.increment
      gauge.increment
      gauge.decrement

      expect(gauge.get).to eq(1)
    end
  end

  describe "histogram" do
    it "registers and observes values" do
      described_class.histogram("request_duration", help: "Request duration", buckets: [0.1, 0.5, 1, 5])
      described_class.observe("request_duration", 0.3)
      described_class.observe("request_duration", 0.8)
      described_class.observe("request_duration", 2.0)

      histogram = described_class.get("request_duration")
      data = histogram.get
      expect(data[:count]).to eq(3)
      expect(data[:sum]).to be_within(0.001).of(3.1)
      expect(data[:buckets][0.1]).to eq(0)
      expect(data[:buckets][0.5]).to eq(1)
      expect(data[:buckets][1]).to eq(2)
      expect(data[:buckets][5]).to eq(3)
    end
  end

  describe ".snapshot" do
    it "returns a snapshot of metric values" do
      described_class.counter("visits", help: "Page visits")
      described_class.increment("visits", labels: { page: "/" })
      described_class.increment("visits", labels: { page: "/about" })

      snap = described_class.snapshot("visits")
      expect(snap.size).to eq(2)
    end
  end

  describe ".to_prometheus" do
    it "exports metrics in Prometheus format" do
      described_class.counter("http_total", help: "Total requests")
      described_class.increment("http_total", labels: { status: "200" })

      output = described_class.to_prometheus
      expect(output).to include("# HELP http_total Total requests")
      expect(output).to include("# TYPE http_total counter")
      expect(output).to include('http_total{status="200"} 1')
    end

    it "exports histogram metrics" do
      described_class.histogram("duration", help: "Duration", buckets: [0.1, 1])
      described_class.observe("duration", 0.5)

      output = described_class.to_prometheus
      expect(output).to include("# TYPE duration histogram")
      expect(output).to include("duration_bucket")
      expect(output).to include("duration_sum")
      expect(output).to include("duration_count")
    end
  end

  describe ".to_json" do
    it "exports metrics as JSON" do
      described_class.counter("events", help: "Events")
      described_class.increment("events")

      json = described_class.to_json
      data = JSON.parse(json)
      expect(data).to have_key("events")
      expect(data["events"]["type"]).to eq("counter")
    end
  end

  describe ".reset" do
    it "clears all metrics" do
      described_class.counter("test_counter", help: "Test")
      described_class.increment("test_counter")
      described_class.reset

      expect { described_class.get("test_counter") }.to raise_error(Philiprehberger::Metric::Error)
    end
  end

  describe "error handling" do
    it "raises on duplicate metric registration" do
      described_class.counter("dup", help: "Duplicate")
      expect { described_class.counter("dup", help: "Duplicate") }.to raise_error(Philiprehberger::Metric::Error)
    end

    it "raises when accessing unregistered metric" do
      expect { described_class.get("nonexistent") }.to raise_error(Philiprehberger::Metric::Error)
    end
  end

  describe "thread safety" do
    it "handles concurrent counter increments" do
      described_class.counter("concurrent", help: "Concurrent")
      threads = Array.new(10) do
        Thread.new do
          100.times { described_class.increment("concurrent") }
        end
      end
      threads.each(&:join)

      counter = described_class.get("concurrent")
      expect(counter.get).to eq(1000)
    end
  end
end
