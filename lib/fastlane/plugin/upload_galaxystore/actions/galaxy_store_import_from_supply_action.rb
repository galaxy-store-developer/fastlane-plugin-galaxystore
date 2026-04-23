require 'fastlane/action'
require 'fileutils'
require_relative '../helper/language_mapper'
require_relative '../helper/shared_options'

module Fastlane
  module Actions
    class GalaxyStoreImportFromSupplyAction < Action
      def self.run(params)
        supply_path = File.join(params[:metadata_path], 'android')
        galaxystore_path = File.join(params[:metadata_path], 'galaxystore')
        default_language_code = params[:default_language_code]
        priority_overrides = params[:language_priority] || {}

        UI.user_error!("Supply metadata directory not found at #{supply_path}") unless Dir.exist?(supply_path)

        # Find all BCP-47 language directories in the Supply folder
        bcp47_dirs = Dir.glob(File.join(supply_path, '*/'))
                        .map { |d| File.basename(d) }
                        .reject { |d| d.start_with?('.') }

        UI.user_error!("No language directories found in #{supply_path}") if bcp47_dirs.empty?

        UI.message("Found Supply language directories: #{bcp47_dirs.join(', ')}")

        # Resolve BCP-47 codes to Galaxy Store language codes
        language_map = Helper::LanguageMapper.resolve_languages(bcp47_dirs, priority_overrides)

        UI.user_error!("No mappable languages found in Supply metadata") if language_map.empty?

        FileUtils.mkdir_p(galaxystore_path)
        UI.message("Writing Galaxy Store metadata to #{galaxystore_path}")

        # Copy icon from the default language's Supply directory
        default_bcp47 = language_map[default_language_code]
        if default_bcp47
          copy_icon(supply_path, default_bcp47, galaxystore_path)
        else
          UI.important("Default language '#{default_language_code}' not found in Supply metadata — icon will not be copied")
        end

        # Copy text metadata and screenshots for each mapped language
        language_map.each do |galaxy_code, bcp47_dir|
          source_dir = File.join(supply_path, bcp47_dir)
          dest_dir = File.join(galaxystore_path, galaxy_code)
          FileUtils.mkdir_p(dest_dir)

          copy_text_files(source_dir, dest_dir)
          copy_screenshots(source_dir, dest_dir, galaxy_code)

          UI.message("Imported #{bcp47_dir} → #{galaxy_code}")
        end

        UI.success("Supply metadata imported to #{galaxystore_path}")
        language_map
      end

      def self.copy_icon(supply_path, bcp47_dir, galaxystore_path)
        icon_path = File.join(supply_path, bcp47_dir, 'images', 'icon.png')
        if File.exist?(icon_path)
          FileUtils.cp(icon_path, File.join(galaxystore_path, 'icon.png'))
          UI.message("Copied icon from #{bcp47_dir}")
        else
          UI.important("No icon found at #{icon_path}")
        end
      end

      def self.copy_text_files(source_dir, dest_dir)
        # title.txt — same filename in both formats
        copy_file(File.join(source_dir, 'title.txt'), File.join(dest_dir, 'title.txt'))

        # short_description.txt — same filename in both formats
        copy_file(File.join(source_dir, 'short_description.txt'), File.join(dest_dir, 'short_description.txt'))

        # full_description.txt (Supply) → long_description.txt (Galaxy Store)
        copy_file(File.join(source_dir, 'full_description.txt'), File.join(dest_dir, 'long_description.txt'))
      end

      def self.copy_screenshots(source_dir, dest_dir, galaxy_code)
        screenshots_source = File.join(source_dir, 'images', 'phoneScreenshots')
        return unless Dir.exist?(screenshots_source)

        screenshots = Dir.glob(File.join(screenshots_source, '*.{png,jpg,jpeg,gif}')).sort
        return if screenshots.empty?

        screenshots_dest = File.join(dest_dir, 'screenshots')
        FileUtils.mkdir_p(screenshots_dest)

        screenshots.each_with_index do |screenshot, index|
          ext = File.extname(screenshot)
          FileUtils.cp(screenshot, File.join(screenshots_dest, "#{index + 1}#{ext}"))
        end

        UI.message("  Copied #{screenshots.length} screenshot(s) for #{galaxy_code}")
      end

      def self.copy_file(source, dest)
        if File.exist?(source)
          FileUtils.cp(source, dest)
        else
          UI.important("  Expected file not found, skipping: #{source}")
        end
      end

      def self.description
        "Imports app metadata from a Fastlane Supply (Google Play) metadata directory into the Galaxy Store format"
      end

      def self.authors
        ["Cristian Lewczyk"]
      end

      def self.return_value
        "Returns a hash mapping Galaxy Store language codes to the BCP-47 directories they were imported from"
      end

      def self.details
        "Reads metadata from fastlane/metadata/android (created by the Supply action for Google Play), " \
          "maps BCP-47 language codes to Galaxy Store language codes, and writes the result to " \
          "fastlane/metadata/galaxystore. When multiple regional variants of a language exist (e.g. es, es-ES, " \
          "es-419), the most appropriate variant is selected automatically with a warning. Use the " \
          "language_priority param to override the selection for specific languages."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            env_name: "GALAXY_STORE_METADATA_PATH",
            description: "Path to the metadata folder containing the 'android' Supply directory",
            optional: true,
            type: String,
            default_value: File.join(Dir.pwd, 'fastlane', 'metadata')
          ),
          FastlaneCore::ConfigItem.new(
            key: :default_language_code,
            env_name: "GALAXY_STORE_DEFAULT_LANGUAGE_CODE",
            description: "Galaxy Store language code for the default listing language. Used to determine which language's icon to use",
            optional: true,
            type: String,
            default_value: 'ENG'
          ),
          FastlaneCore::ConfigItem.new(
            key: :language_priority,
            description: "Hash overriding which BCP-47 variant to use for a given Galaxy Store language code, e.g. { 'SPA' => 'es-419', 'POR' => 'pt-BR' }",
            optional: true,
            type: Hash
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
