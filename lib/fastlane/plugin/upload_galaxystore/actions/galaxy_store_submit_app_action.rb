require 'fastlane/action'
require_relative '../helper/galaxy_store_client'

module Fastlane
  module Actions
    class GalaxyStoreSubmitAppAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        UI.message("Submitting app update for content ID #{params[:content_id]}...")
        result = client.submit_app(params[:content_id])
        UI.success("App submitted successfully")
        result
      end

      def self.description
        "Submits an app update for review on the Samsung Galaxy Store"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the submission response from the Galaxy Store API"
      end

      def self.details
        "Submits a pending app update for the given content ID to the Samsung Galaxy Store for review. " \
        "Can be used standalone after manual edits in the seller portal, or chained after galaxy_store_upload_apk."
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
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
