# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-09

### Added
- `Registry#names`, `Registry#registered?`, and `Registry#unregister` for metric introspection and removal
- Module-level `.names`, `.registered?`, and `.unregister` delegators on `Philiprehberger::Metric`
- `Histogram.linear_buckets` and `Histogram.exponential_buckets` helpers for building bucket boundaries

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-29

### Added
- Summary metric type with configurable quantile estimation
- Timing helper (`registry.time`) to measure block execution duration as histogram observations
- StatsD line protocol export (`to_statsd`) for counters, gauges, histograms, and summaries

## [0.1.2] - 2026-03-24

### Changed
- Expand test coverage to 60+ examples covering edge cases and error paths

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Thread-safe counter, gauge, and histogram metric types
- Label support for dimensional metrics
- Snapshot export per metric
- Prometheus text exposition format output
- JSON output format
- Global registry with reset support
