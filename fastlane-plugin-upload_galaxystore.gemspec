lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/upload_galaxystore/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-upload_galaxystore'
  spec.version       = Fastlane::UploadGalaxystore::VERSION
  spec.author        = 'Cristian Lewczyk'
  spec.email         = 'c.lewczyk@samsung.com'

  spec.summary       = 'This will use the Galaxy Store developer API to upload and Android Build to the Galaxy Store'
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-upload_galaxystore"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.7'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
end
