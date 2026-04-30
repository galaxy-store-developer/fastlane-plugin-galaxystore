require 'digest'
require 'json'

module Fastlane
  module Helper
    module ChecksumStore
      MANIFEST_FILE = '.checksums.json'

      def self.relative_path(file_path, base_path)
        file_path.sub("#{base_path}/", '')
      end

      def self.write(base_path, downloads)
        manifest = {}
        downloads.each do |job|
          next unless File.exist?(job[:dest])

          manifest[relative_path(job[:dest], base_path)] = {
            'md5' => Digest::MD5.file(job[:dest]).hexdigest,
            'remote_url' => job[:url]
          }
        end
        File.write(File.join(base_path, MANIFEST_FILE), manifest.to_json)
      end

      def self.load(base_path)
        path = File.join(base_path, MANIFEST_FILE)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      end

      def self.file_changed?(file_path, base_path, checksums)
        entry = checksums[relative_path(file_path, base_path)]
        return true unless entry

        Digest::MD5.file(file_path).hexdigest != entry['md5']
      end

      def self.remote_url(file_path, base_path, checksums)
        checksums.dig(relative_path(file_path, base_path), 'remote_url')
      end
    end
  end
end
