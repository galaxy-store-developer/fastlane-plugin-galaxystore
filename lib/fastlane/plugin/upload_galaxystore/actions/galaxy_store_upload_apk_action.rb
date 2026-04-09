require 'fastlane/action'
require_relative '../helper/galaxy_store_client'

module Fastlane
  module Actions
    class GalaxyStoreUploadApkAction < Action
      def self.run(params)
        apk_path = params[:apk_path]
        UI.user_error!("File not found at path: #{apk_path}") unless File.exist?(apk_path)

        ext = File.extname(apk_path).downcase
        UI.user_error!("Unsupported file type '#{ext}'. Must be .apk or .aab.") unless ['.apk', '.aab'].include?(ext)

        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]

        UI.message("Creating app update for content ID #{content_id}...")
        client.create_update(content_id)
        UI.message("App update created successfully")

        UI.message("Uploading #{File.basename(apk_path)} to Galaxy Store...")
        upload_result = client.upload_file(apk_path)
        file_key = upload_result['fileKey']
        UI.message("File uploaded successfully, got file key: #{file_key}")

        UI.message("Adding binary to content ID #{content_id}...")
        result = client.add_binary(content_id, file_key)
        UI.success("Binary added successfully")
        result
      end

      def self.description
        "Uploads an APK file to the Samsung Galaxy Store"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the add binary response from the Galaxy Store API"
      end

      def self.details
        "Creates an upload session ID, uploads the binary to the Galaxy Store, then registers it " \
        "against the given content ID. The session creation and file key handoff are handled automatically."
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
            key: :apk_path,
            env_name: "GALAXY_STORE_APK_PATH",
            description: "Path to the .apk or .aab file to upload",
            optional: false,
            type: String
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
