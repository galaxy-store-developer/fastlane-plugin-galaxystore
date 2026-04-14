require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class LanguageMapper
      # Maps BCP-47 base language codes to Galaxy Store language codes
      BCP47_TO_GALAXY = {
        'ar' => 'ARA',
        'bg' => 'BUL',
        'hr' => 'HRV',
        'cs' => 'CES',
        'da' => 'DAN',
        'nl' => 'NLD',
        'en' => 'ENG',
        'et' => 'EST',
        'fi' => 'FIN',
        'fr' => 'FRA',
        'gd' => 'GLA',
        'de' => 'DEU',
        'el' => 'ELL',
        'he' => 'HEB',
        'iw' => 'HEB', # Legacy Hebrew code used by some Android tooling
        'hu' => 'HUN',
        'id' => 'IND',
        'in' => 'IND', # Legacy Indonesian code used by some Android tooling
        'it' => 'ITA',
        'ja' => 'JPN',
        'kk' => 'KAZ',
        'ko' => 'KOR',
        'lv' => 'LAV',
        'lt' => 'LIT',
        'nb' => 'NOR',
        'no' => 'NOR',
        'nn' => 'NOR',
        'fa' => 'FAS',
        'pl' => 'POL',
        'pt' => 'POR',
        'ro' => 'RON',
        'ru' => 'RUS',
        'sr' => 'SRP',
        'sk' => 'SLK',
        'es' => 'SPA',
        'sv' => 'SWE',
        'th' => 'THA',
        'tr' => 'TUR',
        'uk' => 'UKR',
        'vi' => 'VIE'
      }.freeze

      # Chinese requires special handling — Simplified vs Traditional is determined by region
      CHINESE_SIMPLIFIED  = %w[zh-CN zh-Hans zh-SG zh-MY].freeze
      CHINESE_TRADITIONAL = %w[zh-TW zh-Hant zh-HK zh-MO].freeze

      # Default priority order for many-to-one collisions (most preferred first)
      DEFAULT_PRIORITY = {
        'ENG' => %w[en en-US en-GB en-AU en-CA en-IN],
        'FRA' => %w[fr fr-FR fr-CA fr-BE fr-CH],
        'DEU' => %w[de de-DE de-AT de-CH],
        'SPA' => %w[es es-ES es-419 es-US es-MX es-AR es-CO es-CL],
        'POR' => %w[pt pt-PT pt-BR],
        'NOR' => %w[nb no nn],
        'ZHO' => %w[zh-CN zh-Hans zh-SG zh-MY],
        '002' => %w[zh-TW zh-Hant zh-HK zh-MO]
      }.freeze

      # Maps a single BCP-47 code to a Galaxy Store language code.
      # Returns nil if no mapping exists.
      def self.map_bcp47(code)
        return nil if code.nil?

        return 'ZHO' if CHINESE_SIMPLIFIED.include?(code)
        return '002' if CHINESE_TRADITIONAL.include?(code)
        return nil if code.start_with?('zh') # Unknown Chinese variant

        base = code.split('-').first.downcase
        BCP47_TO_GALAXY[base]
      end

      # Takes a list of BCP-47 directory names (as found in a Supply metadata folder),
      # resolves them to Galaxy Store language codes, and returns a hash of:
      #   { galaxy_store_code => selected_bcp47_directory }
      #
      # priority_overrides is an optional hash allowing the developer to specify which
      # BCP-47 variant to prefer for a given Galaxy Store code:
      #   { 'SPA' => 'es-419', 'POR' => 'pt-BR' }
      def self.resolve_languages(bcp47_codes, priority_overrides = {})
        grouped = {}
        skipped = []

        bcp47_codes.each do |code|
          galaxy_code = map_bcp47(code)
          if galaxy_code.nil?
            skipped << code
          else
            grouped[galaxy_code] ||= []
            grouped[galaxy_code] << code
          end
        end

        skipped.each do |code|
          UI.important("No Galaxy Store language mapping found for '#{code}' — skipping")
        end

        result = {}
        grouped.each do |galaxy_code, candidates|
          selected = select_candidate(galaxy_code, candidates, priority_overrides)

          if candidates.length > 1
            UI.important(
              "Multiple variants found for #{galaxy_code} (#{candidates.join(', ')}) — " \
              "using '#{selected}'. Override with language_priority: { '#{galaxy_code}' => 'your-preference' }"
            )
          end

          result[galaxy_code] = selected
        end

        result
      end

      # Selects the best BCP-47 candidate for a given Galaxy Store code.
      def self.select_candidate(galaxy_code, candidates, priority_overrides)
        return candidates.first if candidates.length == 1

        # Check developer-provided override first
        if priority_overrides[galaxy_code]
          preferred = priority_overrides[galaxy_code]
          if candidates.include?(preferred)
            return preferred
          else
            UI.important(
              "language_priority override '#{preferred}' for #{galaxy_code} not found in " \
              "available variants (#{candidates.join(', ')}) — falling back to default"
            )
          end
        end

        # Apply built-in priority list
        priority = DEFAULT_PRIORITY[galaxy_code] || []
        priority.each { |preferred| return preferred if candidates.include?(preferred) }

        # Fall back to first available
        candidates.first
      end
    end
  end
end
