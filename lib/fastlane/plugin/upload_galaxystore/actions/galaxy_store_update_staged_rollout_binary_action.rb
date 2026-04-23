require 'fastlane/action'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreUpdateStagedRolloutBinaryAction < Action
      def self.run(params)
        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]
        function = params[:function].upcase
        binary_seq = params[:binary_seq]

        UI.message("#{function == 'ADD' ? 'Adding' : 'Removing'} binary #{binary_seq} #{function == 'ADD' ? 'to' : 'from'} staged rollout for content ID #{content_id}...")
        result = client.update_staged_rollout_binary(content_id, function, binary_seq)
        UI.success("Binary #{binary_seq} successfully #{function == 'ADD' ? 'added to' : 'removed from'} staged rollout")
        result
      end

      def self.description
        "Adds or removes a binary from the staged rollout group for a Samsung Galaxy Store app"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the staged rollout binary API response"
      end

      def self.details
        "Updates the staged rollout binary group for the given content ID. Use galaxy_store_staged_rollout " \
          "to view available binaries and their binarySeq values before calling this action."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :function,
            description: "Whether to 'ADD' or 'REMOVE' the binary from the staged rollout group",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("function must be 'ADD' or 'REMOVE', got: '#{value}'") unless %w[ADD REMOVE].include?(value.upcase)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :binary_seq,
            description: "The binarySeq of the binary to add or remove. Use galaxy_store_staged_rollout to view available binaries and their sequence numbers",
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
