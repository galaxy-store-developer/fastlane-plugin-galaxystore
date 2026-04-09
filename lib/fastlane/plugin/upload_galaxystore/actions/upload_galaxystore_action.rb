require 'fastlane/action'
require_relative '../helper/upload_galaxystore_helper'

module Fastlane
  module Actions
    class UploadGalaxystoreAction < Action
      def self.run(params)
        UI.message("The upload_galaxystore plugin is working!")
      end

      def self.description
        "This will use the Galaxy Store developer API to upload and Android Build to the Galaxy Store"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Using this plugin requires you to have registered for a Galaxy Store seller account at seller.samsungapps.com  Once you have registered, you can create a new API key via Assitance -> API Service and creating a new service account. Once created, you can use this plugin by providing a service account ID and an auth token. For more information please see: https://developer.samsung.com/galaxy-store/galaxy-store-developer-api.html"
      end

      def self.available_options
        [
          # FastlaneCore::ConfigItem.new(key: :your_option,
          #                         env_name: "UPLOAD_GALAXYSTORE_YOUR_OPTION",
          #                      description: "A description of your option",
          #                         optional: false,
          #                             type: String)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
