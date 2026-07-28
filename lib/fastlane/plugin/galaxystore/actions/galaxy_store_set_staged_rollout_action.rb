require 'fastlane/action'
require 'json'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreSetStagedRolloutAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]
        action = params[:action].upcase
        app_status = params[:app_status].upcase
        function = action == 'ENABLE' ? 'ENABLE_ROLLOUT' : 'DISABLE_ROLLOUT'

        rollout_rate = nil
        countries = nil

        if action == 'ENABLE'
          UI.user_error!("rollout_rate is required when action is ENABLE") unless params[:rollout_rate]
          rollout_rate = params[:rollout_rate]
          countries = resolve_countries(params)
        end

        UI.message("Setting staged rollout for content ID #{content_id} (#{function}, appStatus: #{app_status})...")
        result = client.set_staged_rollout_rate(
          content_id,
          function,
          app_status,
          rollout_rate:,
          countries:
        )

        if action == 'ENABLE'
          UI.success("Staged rollout enabled at #{rollout_rate}%#{countries ? ' (with per-country rates)' : ''}")
        else
          UI.success("Staged rollout disabled")
        end

        result
      end

      def self.resolve_countries(params)
        if params[:countries_json_path]
          UI.important("Both countries_json_path and countries provided — using countries_json_path") if params[:countries]
          path = params[:countries_json_path]
          UI.user_error!("countries_json_path file not found at: #{path}") unless File.exist?(path)
          JSON.parse(File.read(path))
        elsif params[:countries]
          params[:countries]
        end
      end

      def self.description
        "Enables or disables the staged rollout rate for a Samsung Galaxy Store app"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the staged rollout rate API response"
      end

      def self.details
        "Sets the staged rollout rate for the given content ID. Supports a global rollout rate, " \
          "per-country rates hardcoded in the Fastfile via the 'countries' param, or a path to a " \
          "JSON file for complex per-country configurations."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :action,
            env_name: "GALAXY_STORE_ROLLOUT_ACTION",
            description: "Whether to 'ENABLE' or 'DISABLE' the staged rollout",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("action must be 'ENABLE' or 'DISABLE', got: '#{value}'") unless %w[ENABLE DISABLE].include?(value.upcase)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_status,
            env_name: "GALAXY_STORE_APP_STATUS",
            description: "Whether to target live binaries ('SALE') or pending binaries ('REGISTRATION')",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("app_status must be 'SALE' or 'REGISTRATION', got: '#{value}'") unless %w[SALE REGISTRATION].include?(value.upcase)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :rollout_rate,
            env_name: "GALAXY_STORE_ROLLOUT_RATE",
            description: "Global staged rollout percentage (1-100). Required when action is ENABLE",
            optional: true,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :countries,
            description: "Array of per-country rollout rates, e.g. [{countryCode: 'USA', rolloutRate: 40}]. For use when hardcoding in a Fastfile",
            optional: true,
            type: Array
          ),
          FastlaneCore::ConfigItem.new(
            key: :countries_json_path,
            env_name: "GALAXY_STORE_COUNTRIES_JSON_PATH",
            description: "Path to a JSON file containing per-country rollout rates. Takes precedence over the 'countries' param",
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
