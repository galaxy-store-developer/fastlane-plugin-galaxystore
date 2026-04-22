require 'fastlane/action'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require_relative '../helper/galaxy_store_client'

module Fastlane
  module Actions
    class GalaxyStoreAppInfoAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        UI.message("Fetching app info for content ID: #{params[:content_id]}")
        app_info = client.get_app_info(params[:content_id])
        UI.success("Successfully retrieved app info for content ID #{params[:content_id]}")

        write_metadata(app_info, params[:metadata_path])
        write_json(app_info, params[:metadata_path])
        app_info
      end

      def self.write_metadata(app_info, metadata_path)
        galaxystore_path = File.join(metadata_path, 'galaxystore')
        FileUtils.mkdir_p(galaxystore_path)

        entries = Array(app_info)
        entry = entries.find { |e| e['contentStatus'] == 'UPDATING' } ||
                entries.find { |e| e['contentStatus'] == 'FOR_SALE' }

        if entry.nil?
          UI.important("No UPDATING or FOR_SALE listing found — skipping metadata write")
          return
        end

        UI.message("Writing Galaxy Store metadata from #{entry['contentStatus']} listing to #{galaxystore_path}")

        # Default language — top-level fields, always download screenshots
        default_lang_dir = File.join(galaxystore_path, entry['defaultLanguageCode'])
        write_language_files(
          default_lang_dir,
          entry['appTitle'],
          entry['shortDescription'],
          entry['longDescription']
        )
        download_screenshots(Array(entry['screenshots']), default_lang_dir)

        # Additional languages — only download screenshots if the language has its own
        Array(entry['addLanguage']).each do |lang|
          lang_dir = File.join(galaxystore_path, lang['languagecode'])
          write_language_files(
            lang_dir,
            lang['appTitle'],
            lang['shortDescription'],
            lang['description']
          )
          screenshots = Array(lang['screenshots']).reject { |s| s['screenshotPath'].nil? }
          download_screenshots(screenshots, lang_dir) unless screenshots.empty?
        end

        # App icon — shared across languages, saved at the galaxystore level
        download_icon(entry['icon'], galaxystore_path) if entry['icon']

        UI.success("Metadata written from #{entry['contentStatus']} listing")
      end

      def self.write_json(app_info, metadata_path)
        galaxystore_path = File.join(metadata_path, 'galaxystore')
        FileUtils.mkdir_p(galaxystore_path)
        json_path = File.join(galaxystore_path, 'app_info.json')
        File.write(json_path, JSON.pretty_generate(app_info))
        UI.message("Full API response written to #{json_path}")
      end

      def self.download_screenshots(screenshots, lang_dir)
        return if screenshots.empty?

        screenshots_dir = File.join(lang_dir, 'screenshots')
        FileUtils.mkdir_p(screenshots_dir)

        screenshots.each_with_index do |screenshot, index|
          url = screenshot['screenshotPath']
          next if url.nil?

          ext = File.extname(URI(url).path)
          ext = '.png' if ext.empty?
          dest_path = File.join(screenshots_dir, "#{index + 1}#{ext}")

          download_file(url, dest_path)
        end

        UI.message("    Downloaded #{screenshots.length} screenshot(s) to #{screenshots_dir}")
      rescue StandardError => e
        UI.important("  Could not download screenshots for #{File.basename(lang_dir)}: #{e.message}")
      end

      def self.download_icon(icon_url, dest_dir)
        uri = URI(icon_url)
        ext = File.extname(uri.path)
        ext = '.png' if ext.empty?
        dest_path = File.join(dest_dir, "icon#{ext}")
        download_file(icon_url, dest_path)
        UI.message("  Downloaded icon to #{dest_path}")
      rescue StandardError => e
        UI.important("  Could not download icon: #{e.message}")
      end

      def self.download_file(url, dest_path, redirect_limit = 5)
        UI.user_error!("Too many redirects downloading #{url}") if redirect_limit.zero?

        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          response = http.get(uri.request_uri)
          if response.kind_of?(Net::HTTPRedirection)
            download_file(response['location'], dest_path, redirect_limit - 1)
          else
            File.binwrite(dest_path, response.body)
          end
        end
      end

      def self.write_language_files(dir_path, title, short_description, long_description)
        FileUtils.mkdir_p(dir_path)
        File.write(File.join(dir_path, 'title.txt'), title.to_s)
        File.write(File.join(dir_path, 'short_description.txt'), short_description.to_s)
        File.write(File.join(dir_path, 'long_description.txt'), long_description.to_s)
        UI.message("  #{File.basename(dir_path)}: title, short_description, long_description")
      end

      def self.description
        "Retrieves app information from the Samsung Galaxy Store and writes metadata to local files"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the app information from the Galaxy Store API"
      end

      def self.details
        "Uses the Galaxy Store Content Publish API to retrieve detailed information about an app and " \
          "writes metadata to metadata/galaxystore/<language_code>/. Prefers the UPDATING listing if one " \
          "exists, otherwise falls back to the FOR_SALE listing."
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
