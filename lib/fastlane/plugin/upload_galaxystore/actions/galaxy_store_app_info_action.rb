require 'fastlane/action'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreAppInfoAction < Action
      DOWNLOAD_TIMEOUT = 30

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

        entries = Array(app_info)
        entry = entries.find { |e| e['contentStatus'] == 'REGISTERING' } ||
                entries.find { |e| e['contentStatus'] == 'FOR_SALE' }

        if entry.nil?
          UI.important("No REGISTERING or FOR_SALE listing found — skipping metadata write")
          FileUtils.mkdir_p(galaxystore_path)
          return
        end

        FileUtils.rm_rf(galaxystore_path)
        FileUtils.mkdir_p(galaxystore_path)

        UI.message("Writing Galaxy Store metadata from #{entry['contentStatus']} listing to #{galaxystore_path}")

        downloads = []

        default_lang_dir = File.join(galaxystore_path, entry['defaultLanguageCode'])
        write_language_files(default_lang_dir, entry['appTitle'], entry['shortDescription'], entry['longDescription'])
        collect_screenshot_downloads(Array(entry['screenshots']), default_lang_dir, downloads)

        Array(entry['addLanguage']).each do |lang|
          lang_dir = File.join(galaxystore_path, lang['languagecode'])
          write_language_files(lang_dir, lang['appTitle'], lang['shortDescription'], lang['description'])
          screenshots = Array(lang['screenshots']).reject { |s| s['screenshotPath'].nil? }
          collect_screenshot_downloads(screenshots, lang_dir, downloads) unless screenshots.empty?
        end

        if entry['icon']
          uri = URI(entry['icon'])
          ext = File.extname(uri.path)
          ext = '.png' if ext.empty?
          downloads << { url: entry['icon'], dest: File.join(galaxystore_path, "icon#{ext}") }
        end

        download_files(downloads)

        UI.success("Metadata written from #{entry['contentStatus']} listing")
      end

      def self.write_json(app_info, metadata_path)
        galaxystore_path = File.join(metadata_path, 'galaxystore')
        json_path = File.join(galaxystore_path, 'app_info.json')
        File.write(json_path, JSON.pretty_generate(app_info))
        UI.message("Full API response written to #{json_path}")
      end

      def self.collect_screenshot_downloads(screenshots, lang_dir, downloads)
        return if screenshots.empty?

        screenshots_dir = File.join(lang_dir, 'screenshots')
        FileUtils.mkdir_p(screenshots_dir)

        screenshots.each_with_index do |screenshot, index|
          url = screenshot['screenshotPath']
          next if url.nil?

          ext = File.extname(URI(url).path)
          ext = '.png' if ext.empty?
          downloads << { url: url, dest: File.join(screenshots_dir, "#{index + 1}#{ext}") }
        end
      end

      def self.download_files(downloads)
        return if downloads.empty?

        by_host = downloads.group_by { |d| URI(d[:url]).host }

        threads = by_host.map do |_host, jobs|
          Thread.new do
            first_uri = URI(jobs.first[:url])
            Net::HTTP.start(first_uri.host, first_uri.port, use_ssl: first_uri.scheme == 'https',
                            open_timeout: DOWNLOAD_TIMEOUT, read_timeout: DOWNLOAD_TIMEOUT) do |http|
              jobs.each do |job|
                download_with_connection(http, job[:url], job[:dest])
              rescue StandardError => e
                UI.important("  Could not download #{File.basename(job[:dest])}: #{e.message}")
              end
            end
          rescue StandardError => e
            UI.important("  Connection failed for #{first_uri.host}: #{e.message}")
          end
        end

        threads.each(&:join)
        UI.message("  Downloaded #{downloads.length} file(s)")
      end

      def self.download_with_connection(http, url, dest_path, redirect_limit = 5)
        UI.user_error!("Too many redirects downloading #{url}") if redirect_limit.zero?

        uri = URI(url)

        # Redirect may point to a different host; open a fresh connection for it
        unless uri.host == http.address
          return download_single(url, dest_path, redirect_limit)
        end

        response = http.get(uri.request_uri)
        if response.is_a?(Net::HTTPRedirection)
          download_single(response['location'], dest_path, redirect_limit - 1)
        else
          File.binwrite(dest_path, response.body)
        end
      end

      def self.download_single(url, dest_path, redirect_limit = 5)
        UI.user_error!("Too many redirects downloading #{url}") if redirect_limit.zero?

        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = DOWNLOAD_TIMEOUT
        http.read_timeout = DOWNLOAD_TIMEOUT

        response = http.get(uri.request_uri)
        if response.is_a?(Net::HTTPRedirection)
          download_single(response['location'], dest_path, redirect_limit - 1)
        else
          File.binwrite(dest_path, response.body)
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
          "writes metadata to metadata/galaxystore/<language_code>/. Prefers the REGISTERING listing if one " \
          "exists, otherwise falls back to the FOR_SALE listing."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
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
