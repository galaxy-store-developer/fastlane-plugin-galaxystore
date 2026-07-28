require 'fastlane/action'
require 'fileutils'
require 'json'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

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

        if params[:output_path]
          FileUtils.mkdir_p(File.dirname(params[:output_path]))
          File.write(params[:output_path], JSON.pretty_generate(result))
          UI.message("App list written to #{params[:output_path]}")
        end

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
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          FastlaneCore::ConfigItem.new(
            key: :output_path,
            env_name: "GALAXY_STORE_APP_LIST_OUTPUT_PATH",
            description: "Path to write the app list JSON file. When omitted, the result is only returned",
            optional: true,
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
