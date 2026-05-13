lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/upload_galaxystore/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-upload_galaxystore'
  spec.version       = Fastlane::UploadGalaxystore::VERSION
  spec.author        = 'Cristian Lewczyk'
  spec.email         = 'c.lewczyk@samsung.com'

  spec.summary       = 'Fastlane plugin for managing Android app releases on the Samsung Galaxy Store'
  spec.description   = 'A fastlane plugin that wraps the Samsung Galaxy Store Developer API. ' \
                       'Provides actions for uploading APK/AAB binaries, syncing store listing ' \
                       'metadata (including import from Google Play Supply), submitting apps for ' \
                       'review, controlling publication timing, and managing staged rollouts.'
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-upload_galaxystore"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md CHANGELOG.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 3.1'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
end
