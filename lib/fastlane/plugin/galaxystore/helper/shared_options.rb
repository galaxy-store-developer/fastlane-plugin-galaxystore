module Fastlane
  module Helper
    module SharedOptions
      def self.access_token
        FastlaneCore::ConfigItem.new(
          key: :access_token,
          env_name: "GALAXY_STORE_ACCESS_TOKEN",
          description: "Access token for Galaxy Store API authentication",
          optional: false,
          sensitive: true,
          type: String
        )
      end

      def self.service_account_id
        FastlaneCore::ConfigItem.new(
          key: :service_account_id,
          env_name: "GALAXY_STORE_SERVICE_ACCOUNT_ID",
          description: "Service account ID for Galaxy Store API authentication",
          optional: false,
          sensitive: true,
          type: String
        )
      end

      def self.content_id
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
      end
    end
  end
end
