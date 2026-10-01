lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/galaxystore/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-galaxystore'
  spec.version       = Fastlane::Galaxystore::VERSION
  spec.author        = 'Cristian Lewczyk'
  spec.email         = 'c.lewczyk@samsung.com'

  spec.summary       = 'Fastlane plugin for managing Android app releases on the Samsung Galaxy Store'
  spec.description   = 'A fastlane plugin that wraps the Samsung Galaxy Store Developer API. ' \
                       'Provides actions for uploading APK/AAB binaries, syncing store listing ' \
                       'metadata (including import from Google Play Supply), submitting apps for ' \
                       'review, controlling publication timing, and managing staged rollouts.'
  spec.homepage      = "https://github.com/galaxy-store-developer/fastlane-plugin-galaxystore"
  spec.license       = "Apache-2.0"

  spec.files         = Dir["lib/**/*"] + %w(README.md CHANGELOG.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/galaxy-store-developer/fastlane-plugin-galaxystore'
  spec.metadata['changelog_uri'] = 'https://github.com/galaxy-store-developer/fastlane-plugin-galaxystore/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/galaxy-store-developer/fastlane-plugin-galaxystore/issues'
  spec.required_ruby_version = '>= 3.1'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'

  # Provides a consistent environment for Ruby projects by tracking and installing exact gem versions.
  spec.add_development_dependency('bundler')
  # Automation tool for mobile developers.
  spec.add_development_dependency('fastlane', '>= 2.232.2')
  # Provides an interactive debugging environment for Ruby.
  spec.add_development_dependency('pry')
  # A simple task automation tool.
  spec.add_development_dependency('rake')
  # Behavior-driven testing tool for Ruby.
  spec.add_development_dependency('rspec')
  # Formatter for RSpec to generate JUnit compatible reports.
  spec.add_development_dependency('rspec_junit_formatter')
  # A Ruby static code analyzer and formatter.
  spec.add_development_dependency('rubocop', '1.50.2')
  # A collection of RuboCop cops for performance optimizations.
  spec.add_development_dependency('rubocop-performance')
  # A RuboCop extension focused on enforcing tools.
  spec.add_development_dependency('rubocop-require_tools')
  # SimpleCov is a code coverage analysis tool for Ruby.
  spec.add_development_dependency('simplecov')
  # Lightweight HTTP server used in specs for download testing.
  spec.add_development_dependency('webrick')
end
