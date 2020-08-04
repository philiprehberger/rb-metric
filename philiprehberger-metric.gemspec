# frozen_string_literal: true

require_relative 'lib/philiprehberger/metric/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-metric'
  spec.version = Philiprehberger::Metric::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'In-process application metrics with counters, gauges, histograms, and summaries'
  spec.description = 'A thread-safe in-process metrics library providing counters, gauges, histograms, and summaries ' \
                     'with label support, timing helpers, and Prometheus, JSON, and StatsD export formats.'
  spec.homepage = 'https://github.com/philiprehberger/rb-metric'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
