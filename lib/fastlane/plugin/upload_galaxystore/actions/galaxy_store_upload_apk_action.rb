require 'fastlane/action'
require_relative '../helper/galaxy_store_client'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    module SharedValues
      GALAXY_STORE_BINARY_SEQ = :GALAXY_STORE_BINARY_SEQ
    end

    class GalaxyStoreUploadApkAction < Action
      def self.run(params)
        apk_path = params[:apk_path] || resolve_from_lane_context
        UI.user_error!("No APK/AAB path provided and none found in lane context. Set apk_path or run the gradle action first.") if apk_path.nil?
        UI.user_error!("File not found at path: #{apk_path}") unless File.exist?(apk_path)

        ext = File.extname(apk_path).downcase
        UI.user_error!("Unsupported file type '#{ext}'. Must be .apk or .aab.") unless ['.apk', '.aab'].include?(ext)

        client = Helper::GalaxyStoreClient.new(
          params[:service_account_id],
          params[:access_token]
        )

        content_id = params[:content_id]

        UI.message("Creating app update for content ID #{content_id}...")
        client.create_update(content_id)
        UI.message("App update created successfully")

        UI.message("Uploading #{File.basename(apk_path)} to Galaxy Store...")
        upload_result = client.upload_file(apk_path)
        file_key = upload_result['fileKey']
        UI.message("File uploaded successfully, got file key: #{file_key}")

        UI.message("Adding binary to content ID #{content_id}...")
        result = client.add_binary(content_id, file_key, gms: params[:gms]&.upcase)

        binary_seq = result.dig('data', 'binarySeq')
        if binary_seq
          Actions.lane_context[SharedValues::GALAXY_STORE_BINARY_SEQ] = binary_seq
          UI.success("Binary added successfully (binarySeq: #{binary_seq})")
        else
          UI.success("Binary added successfully")
          UI.important("Galaxy Store did not return a binarySeq — staged rollout chaining will not work for this run")
        end

        binary_seq
      end

      def self.description
        "Uploads an APK file to the Samsung Galaxy Store"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns the binarySeq (string) of the newly added binary, or nil if the API did not return one"
      end

      def self.output
        [
          ['GALAXY_STORE_BINARY_SEQ', 'The binarySeq of the binary just added to the app, suitable for chaining into galaxy_store_update_staged_rollout_binary']
        ]
      end

      def self.details
        "Creates an upload session ID, uploads the binary to the Galaxy Store, then registers it " \
          "against the given content ID. The session creation and file key handoff are handled automatically."
      end

      def self.available_options
        [
          Helper::SharedOptions.access_token,
          Helper::SharedOptions.service_account_id,
          Helper::SharedOptions.content_id,
          FastlaneCore::ConfigItem.new(
            key: :apk_path,
            env_name: "GALAXY_STORE_APK_PATH",
            description: "Path to the .apk or .aab file to upload. If omitted, falls back to the gradle lane context (GRADLE_ALL_AAB_OUTPUT_PATHS, GRADLE_AAB_OUTPUT_PATH, GRADLE_ALL_APK_OUTPUT_PATHS, GRADLE_APK_OUTPUT_PATH)",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :gms,
            env_name: "GALAXY_STORE_GMS",
            description: "Whether the binary uses Google Mobile Services: 'Y' if your build includes the Play Services SDK, 'N' otherwise. This value rarely changes between releases for a given app — hardcode it in your Fastfile",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("gms must be 'Y' or 'N', got: '#{value}'") unless %w[Y N].include?(value.upcase)
            end
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      private_class_method def self.resolve_from_lane_context
        # Prefer AAB — only use GRADLE_ALL_AAB_OUTPUT_PATHS if there is exactly one
        all_aabs = Actions.lane_context[SharedValues::GRADLE_ALL_AAB_OUTPUT_PATHS] || []
        return all_aabs.first if all_aabs.size == 1

        aab = Actions.lane_context[SharedValues::GRADLE_AAB_OUTPUT_PATH]
        return aab if aab

        # Fall back to APK — same single-entry rule for the multi-path value
        all_apks = Actions.lane_context[SharedValues::GRADLE_ALL_APK_OUTPUT_PATHS] || []
        return all_apks.first if all_apks.size == 1

        Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH]
      end
    end
  end
end
