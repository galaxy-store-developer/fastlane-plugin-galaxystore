require 'fastlane/action'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreSetPublicationTypeAction < Action
      def self.run(params)
        publication_type = params[:publication_type]
        start_publication_date = params[:start_publication_date]

        if publication_type == '02' && start_publication_date.nil?
          UI.user_error!("start_publication_date is required when publication_type is '02' (Publish on date)")
        end

        if publication_type != '02' && !start_publication_date.nil?
          UI.important("start_publication_date is set but publication_type is '#{publication_type}' — date will be ignored")
        end

        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        payload = { contentId: params[:content_id], publicationType: publication_type }
        payload[:startPublicationDate] = start_publication_date if publication_type == '02'

        UI.message("Setting publication type to '#{publication_type}' for content ID #{params[:content_id]}...")
        result = client.update_content_metadata(payload)
        UI.success("Publication type set successfully")
        result
      end

      def self.description
        "Sets the publication type for a Samsung Galaxy Store app update"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash containing the contentUpdate response from the Galaxy Store API"
      end

      def self.details
        "Configures how and when an app update goes live after passing review. Must be called before " \
          "galaxy_store_submit_app. Use '01' to publish automatically after Pre-Review, '02' to publish " \
          "on a specific date, or '03' to publish manually via galaxy_store_publish_app."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :publication_type,
            env_name: "GALAXY_STORE_PUBLICATION_TYPE",
            description: "Publication type: '01' = automatic after Pre-Review, '02' = on a specific date, '03' = manual",
            optional: true,
            type: String,
            default_value: '01',
            verify_block: proc do |value|
              UI.user_error!("publication_type must be '01', '02', or '03', got: '#{value}'") unless %w[01 02 03].include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :start_publication_date,
            env_name: "GALAXY_STORE_START_PUBLICATION_DATE",
            description: "Date and time to publish the app, in 'yyyy-MM-dd HH:mm:ss' format. Required when publication_type is '02'",
            optional: true,
            type: String,
            verify_block: proc do |value|
              unless value.match?(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
                UI.user_error!("start_publication_date must be in 'yyyy-MM-dd HH:mm:ss' format, got: '#{value}'")
              end
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
