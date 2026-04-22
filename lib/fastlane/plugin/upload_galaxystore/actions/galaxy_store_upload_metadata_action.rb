require 'fastlane/action'
require_relative '../helper/galaxy_store_client'

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

        # Upload icon
        icon_key = nil
        if metadata[:icon_path]
          UI.message("Uploading icon...")
          result = client.upload_file(metadata[:icon_path])
          icon_key = result['fileKey']
          UI.message("Icon uploaded, file key: #{icon_key}")
        end

        # Upload screenshots per language
        screenshot_keys = {}
        metadata[:languages].each do |lang_code, lang_data|
          next unless lang_data[:screenshots]&.any?

          screenshot_keys[lang_code] = []
          lang_data[:screenshots].each do |path|
            UI.message("Uploading screenshot for #{lang_code}: #{File.basename(path)}")
            result = client.upload_file(path)
            screenshot_keys[lang_code] << result['fileKey']
          end
        end

        payload = build_payload(content_id, default_language_code, metadata, icon_key, screenshot_keys)

        UI.message("Updating app metadata for content ID #{content_id}...")
        result = client.update_content_metadata(payload)
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

      def self.build_payload(content_id, default_language_code, metadata, icon_key, screenshot_keys)
        default_lang = metadata[:languages][default_language_code] || {}

        payload = {
          contentId: content_id,
          defaultLanguageCode: default_language_code,
          iconKey: icon_key
        }

        payload[:appTitle] = default_lang[:title] if default_lang[:title]
        payload[:shortDescription] = default_lang[:short_description] if default_lang[:short_description]
        payload[:longDescription] = default_lang[:long_description] if default_lang[:long_description]

        if screenshot_keys[default_language_code]&.any?
          payload[:screenshots] = screenshot_keys[default_language_code].map do |key|
            { screenshotPath: nil, screenshotKey: key, reuseYn: false }
          end
        end

        additional_languages = metadata[:languages].reject { |code, _| code == default_language_code }
        unless additional_languages.empty?
          payload[:addLanguage] = additional_languages.map do |lang_code, lang_data|
            lang_entry = { languagecode: lang_code }
            lang_entry[:appTitle] = lang_data[:title] if lang_data[:title]
            lang_entry[:shortDescription] = lang_data[:short_description] if lang_data[:short_description]
            lang_entry[:description] = lang_data[:long_description] if lang_data[:long_description]

            if screenshot_keys[lang_code]&.any?
              lang_entry[:screenshots] = screenshot_keys[lang_code].map do |key|
                { screenshotPath: nil, screenshotKey: key, reuseYn: false }
              end
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
          FastlaneCore::ConfigItem.new(
            key: :access_token,
            env_name: "GALAXY_STORE_ACCESS_TOKEN",
            description: "Access token for Galaxy Store API authentication",
            optional: false,
            sensitive: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :service_account_id,
            env_name: "GALAXY_STORE_SERVICE_ACCOUNT_ID",
            description: "Service account ID for Galaxy Store API authentication",
            optional: false,
            sensitive: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :content_id,
            env_name: "GALAXY_STORE_CONTENT_ID",
            description: "12-digit content ID of the app in the Galaxy Store",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("Content ID must be a 12-digit number, got: '#{value}'") unless value.match?(/^\d{12}$/)
            end
          ),
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
