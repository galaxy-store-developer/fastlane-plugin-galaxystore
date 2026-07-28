require 'fastlane/action'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreStagedRolloutAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]
        app_status = params[:app_status].upcase

        UI.message("Fetching staged rollout binaries for content ID #{content_id} (appStatus: #{app_status})...")
        binaries = client.get_staged_rollout_binaries(content_id, app_status)

        UI.verbose("Raw staged rollout binary response: #{binaries.inspect}")

        binary_list = binaries.dig('data', 'binaries') || []

        if binary_list.empty?
          UI.message("No binaries found for content ID #{content_id}.")
          return nil
        end

        UI.message("Binaries:")
        binary_list.each do |binary|
          UI.message("  Seq: #{binary['seq']}  |  Version: #{binary['versionName']}  |  Rollout status: #{binary['rolloutStatus']}")
        end

        rollout_enabled = binary_list.any? { |b| b['rolloutStatus']&.upcase == 'ENABLED' }

        unless rollout_enabled
          UI.message("No binaries have staged rollout enabled.")
          return { binaries: binary_list, rollout_rate: nil }
        end

        UI.message("Staged rollout is enabled — fetching rollout rate...")
        rate_info = client.get_staged_rollout_rate(content_id, app_status)
        UI.verbose("Raw staged rollout rate response: #{rate_info.inspect}")
        rate_data = rate_info['data']
        countries = rate_data['countries']

        if countries.nil? || countries.empty?
          UI.success("Staged rollout rate: #{rate_data['rolloutRate']}% (all countries)")
        else
          UI.success("Staged rollout rates by country:")
          countries.each do |entry|
            UI.success("  #{entry['countryCode']}: #{entry['rolloutRate']}%")
          end
        end

        { binaries: binary_list, rollout_rate: rate_data }
      end

      def self.description
        "Checks the staged rollout status and rate for binaries registered to a Galaxy Store app"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash with 'binaries' (array of binary info) and 'rollout_rate' (rate info hash, or nil if rollout is not enabled)"
      end

      def self.details
        "Fetches the list of binaries with staged rollout applied for the given content ID and app status. " \
          "If any binary has staged rollout enabled, also fetches and displays the current rollout rate."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :app_status,
            env_name: "GALAXY_STORE_APP_STATUS",
            description: "Whether to check staged rollout for live binaries ('SALE') or binaries being registered ('REGISTRATION')",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("app_status must be 'SALE' or 'REGISTRATION', got: '#{value}'") unless %w[SALE REGISTRATION].include?(value.upcase)
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
