require 'fastlane/action'
require_relative '../helper/galaxy_store_client'

module Fastlane
  module Actions
    class GalaxyStorePublishAppAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        UI.message("Setting app status to FOR_SALE for content ID #{params[:content_id]}...")
        result = client.update_content_status(params[:content_id], 'FOR_SALE')
        UI.success("App is now FOR_SALE")
        result
      end

      def self.description
        "Sets a Samsung Galaxy Store app's status to FOR_SALE"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the contentStatusUpdate response from the Galaxy Store API"
      end

      def self.details
        "Moves the app to the FOR_SALE state via the Galaxy Store Content Publish API. Intended for use " \
          "after galaxy_store_submit_app when the app was submitted with the Manual Publication option, " \
          "allowing the publisher to control when the update goes live."
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
