require 'fastlane/action'
require_relative '../helper/galaxy_store_client'

module Fastlane
  module Actions
    class GalaxyStoreAppListAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        UI.message("Retrieving app list from Galaxy Store...")
        result = client.get_app_list
        UI.success("Retrieved #{result.length} app(s)")
        result
      end

      def self.description
        "Retrieves the list of all apps registered to a Samsung Galaxy Store seller account"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns an array of hashes, each containing app information for a registered app"
      end

      def self.details
        "Uses the Galaxy Store Content Publish API to retrieve all apps associated with the " \
          "authenticated seller account."
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
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
