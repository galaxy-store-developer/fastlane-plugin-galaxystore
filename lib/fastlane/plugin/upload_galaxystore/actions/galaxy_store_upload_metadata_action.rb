require 'digest'
require 'fastlane/action'
require 'json'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreUploadMetadataAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]
        default_language_code = params[:default_language_code]
        galaxystore_path = File.join(params[:metadata_path], 'galaxystore')

        unless Dir.exist?(galaxystore_path)
          UI.user_error!("Galaxy Store metadata directory not found at #{galaxystore_path}. " \
                         "Run the galaxy_store_app_info action first to download your app's metadata and make local edits.")
        end

        metadata = scan_metadata(galaxystore_path)
        validate_metadata(metadata)
        checksums = load_checksums(galaxystore_path)

        icon_key = upload_icon_if_changed(client, metadata[:icon_path], galaxystore_path, checksums)

        screenshot_entries = {}
        metadata[:languages].each do |lang_code, lang_data|
          next unless lang_data[:screenshots]&.any?

          screenshot_entries[lang_code] = upload_screenshots_if_changed(
            client, lang_code, lang_data[:screenshots], galaxystore_path, checksums
          )
        end

        payload = build_payload(content_id, default_language_code, metadata, icon_key, screenshot_entries)

        UI.message("Updating app metadata for content ID #{content_id}...")
        begin
          result = client.update_content_metadata(payload)
        rescue FastlaneCore::Interface::FastlaneError => e
          diagnose_api_error(e.message, metadata) if e.message.include?('400')
          raise
        end
        UI.success("Metadata updated successfully")
        result
      end

      def self.scan_metadata(galaxystore_path)
        metadata = { languages: {} }

        icon_files = Dir.glob(File.join(galaxystore_path, 'icon.*'))
        metadata[:icon_path] = icon_files.first
        UI.message("Found icon: #{metadata[:icon_path]}") if metadata[:icon_path]

        Dir.glob(File.join(galaxystore_path, '*/'), sort: true).each do |lang_dir|
          lang_code = File.basename(lang_dir)
          lang_data = {}

          title_file = File.join(lang_dir, 'title.txt')
          lang_data[:title] = File.read(title_file).strip if File.exist?(title_file)

          short_desc_file = File.join(lang_dir, 'short_description.txt')
          lang_data[:short_description] = File.read(short_desc_file).strip if File.exist?(short_desc_file)

          long_desc_file = File.join(lang_dir, 'long_description.txt')
          lang_data[:long_description] = File.read(long_desc_file).strip if File.exist?(long_desc_file)

          screenshots_dir = File.join(lang_dir, 'screenshots')
          if Dir.exist?(screenshots_dir)
            lang_data[:screenshots] = Dir.glob(File.join(screenshots_dir, '*.{png,jpg,jpeg,gif}')).sort
          end

          metadata[:languages][lang_code] = lang_data
          UI.message("Found metadata for language: #{lang_code}")
        end

        metadata
      end

      SHORT_DESC_MIN_BYTES = 20
      SHORT_DESC_MAX_BYTES = 240

      def self.validate_metadata(metadata)
        errors = []
        metadata[:languages].each do |lang_code, lang_data|
          next unless lang_data[:short_description]

          byte_len = lang_data[:short_description].bytesize
          next if byte_len >= SHORT_DESC_MIN_BYTES && byte_len <= SHORT_DESC_MAX_BYTES

          errors << "#{lang_code}: short_description is #{byte_len} bytes (must be #{SHORT_DESC_MIN_BYTES}–#{SHORT_DESC_MAX_BYTES})"
        end

        return if errors.empty?

        UI.user_error!("Metadata validation failed:\n  #{errors.join("\n  ")}")
      end

      FIELD_PATTERNS = {
        'short description' => :short_description,
        'long description' => :long_description,
        'title' => :title
      }.freeze

      def self.diagnose_api_error(error_message, metadata)
        json_str = error_message[/\{.+\}/m]
        return unless json_str

        parsed = JSON.parse(json_str)
        error_msg = parsed.dig('body', 'errorMsg') || parsed['message'] || ''

        field_key = FIELD_PATTERNS.find { |pattern, _| error_msg.downcase.include?(pattern) }&.last
        return unless field_key

        UI.error("Per-language breakdown for #{field_key}:")
        metadata[:languages].each do |lang_code, lang_data|
          value = lang_data[field_key]
          next unless value

          UI.error("  #{lang_code}: #{value.bytesize} bytes — #{value[0..60].inspect}#{'...' if value.length > 60}")
        end
      rescue JSON::ParserError
        nil
      end

      def self.load_checksums(galaxystore_path)
        path = File.join(galaxystore_path, '.checksums.json')
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      end

      def self.file_changed?(file_path, galaxystore_path, checksums)
        relative = file_path.sub("#{galaxystore_path}/", '')
        entry = checksums[relative]
        return true unless entry

        Digest::MD5.file(file_path).hexdigest != entry['md5']
      end

      def self.upload_icon_if_changed(client, icon_path, galaxystore_path, checksums)
        return nil unless icon_path

        unless file_changed?(icon_path, galaxystore_path, checksums)
          UI.message("Icon unchanged, skipping upload")
          return nil
        end

        UI.message("Uploading icon...")
        result = client.upload_file(icon_path)
        UI.message("Icon uploaded, file key: #{result['fileKey']}")
        result['fileKey']
      end

      def self.upload_screenshots_if_changed(client, lang_code, paths, galaxystore_path, checksums)
        paths.map do |path|
          if file_changed?(path, galaxystore_path, checksums)
            UI.message("Uploading screenshot for #{lang_code}: #{File.basename(path)}")
            result = client.upload_file(path)
            { screenshotPath: nil, screenshotKey: result['fileKey'], reuseYn: false }
          else
            relative = path.sub("#{galaxystore_path}/", '')
            remote_url = checksums.dig(relative, 'remote_url')
            UI.message("Screenshot unchanged for #{lang_code}: #{File.basename(path)}, reusing")
            { screenshotPath: remote_url, screenshotKey: nil, reuseYn: true }
          end
        end
      end

      def self.build_payload(content_id, default_language_code, metadata, icon_key, screenshot_entries)
        default_lang = metadata[:languages][default_language_code] || {}

        payload = {
          contentId: content_id,
          defaultLanguageCode: default_language_code
        }
        payload[:iconKey] = icon_key if icon_key

        payload[:appTitle] = default_lang[:title] if default_lang[:title]
        payload[:shortDescription] = default_lang[:short_description] if default_lang[:short_description]
        payload[:longDescription] = default_lang[:long_description] if default_lang[:long_description]

        if screenshot_entries[default_language_code]&.any?
          payload[:screenshots] = screenshot_entries[default_language_code]
        end

        additional_languages = metadata[:languages].reject { |code, _| code == default_language_code }
        unless additional_languages.empty?
          payload[:addLanguage] = additional_languages.map do |lang_code, lang_data|
            lang_entry = { languagecode: lang_code }
            lang_entry[:appTitle] = lang_data[:title] if lang_data[:title]
            lang_entry[:shortDescription] = lang_data[:short_description] if lang_data[:short_description]
            lang_entry[:description] = lang_data[:long_description] if lang_data[:long_description]

            if screenshot_entries[lang_code]&.any?
              lang_entry[:screenshots] = screenshot_entries[lang_code]
            end

            lang_entry
          end
        end

        payload
      end

      def self.description
        "Uploads app metadata from the local galaxystore metadata directory to the Samsung Galaxy Store"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the contentUpdate response from the Galaxy Store API"
      end

      def self.details
        "Scans fastlane/metadata/galaxystore for title, short description, long description, icon, and " \
          "screenshots per language. Uploads any image assets to get file keys, then submits everything " \
          "via the contentUpdate API."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :default_language_code,
            env_name: "GALAXY_STORE_DEFAULT_LANGUAGE_CODE",
            description: "Language code for the default listing language (e.g. ENG)",
            optional: true,
            type: String,
            default_value: 'ENG'
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            env_name: "GALAXY_STORE_METADATA_PATH",
            description: "Path to the metadata folder",
            optional: true,
            type: String,
            default_value: File.join(Dir.pwd, 'fastlane', 'metadata')
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
