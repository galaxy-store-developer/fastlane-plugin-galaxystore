require 'fastlane/plugin/upload_galaxystore'
require 'tmpdir'
require 'fileutils'

describe Fastlane::Actions::GalaxyStoreUploadMetadataAction do
  let(:action) { described_class }

  # Builds a galaxystore metadata directory structure for tests.
  def build_galaxystore_dir(base, languages: {}, icon: false)
    gs_path = File.join(base, 'galaxystore')
    FileUtils.mkdir_p(gs_path)

    File.write(File.join(gs_path, 'icon.png'), 'fake_icon') if icon

    languages.each do |lang_code, data|
      lang_dir = File.join(gs_path, lang_code)
      FileUtils.mkdir_p(lang_dir)

      File.write(File.join(lang_dir, 'title.txt'), data[:title]) if data[:title]
      File.write(File.join(lang_dir, 'short_description.txt'), data[:short_description]) if data[:short_description]
      File.write(File.join(lang_dir, 'long_description.txt'), data[:long_description]) if data[:long_description]

      next unless data[:screenshots]

      screenshots_dir = File.join(lang_dir, 'screenshots')
      FileUtils.mkdir_p(screenshots_dir)
      data[:screenshots].each_with_index do |name, i|
        File.write(File.join(screenshots_dir, name), "screenshot_#{i}")
      end
    end

    gs_path
  end

  describe '.scan_metadata' do
    it 'reads title, short_description, and long_description from each language directory' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp,
                              languages: {
                                'ENG' => {
                                  title: 'My App',
                                  short_description: 'A great app',
                                  long_description: 'This is a detailed description.'
                                }
                              })

        result = action.scan_metadata(File.join(tmp, 'galaxystore'))

        eng = result[:languages]['ENG']
        expect(eng[:title]).to eq('My App')
        expect(eng[:short_description]).to eq('A great app')
        expect(eng[:long_description]).to eq('This is a detailed description.')
      end
    end

    it 'detects the icon file' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp, languages: {}, icon: true)

        result = action.scan_metadata(File.join(tmp, 'galaxystore'))

        expect(result[:icon_path]).to end_with('icon.png')
      end
    end

    it 'returns nil for icon_path when no icon exists' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp, languages: {}, icon: false)

        result = action.scan_metadata(File.join(tmp, 'galaxystore'))

        expect(result[:icon_path]).to be_nil
      end
    end

    it 'collects screenshot paths sorted alphabetically' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp,
                              languages: {
                                'ENG' => { screenshots: ['1.png', '2.png', '3.png'] }
                              })

        result = action.scan_metadata(File.join(tmp, 'galaxystore'))

        screenshots = result[:languages]['ENG'][:screenshots]
        expect(screenshots.length).to eq(3)
        expect(screenshots.map { |p| File.basename(p) }).to eq(['1.png', '2.png', '3.png'])
      end
    end

    it 'handles missing optional files gracefully (no title, no screenshots)' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp,
                              languages: { 'KOR' => {} })

        result = action.scan_metadata(File.join(tmp, 'galaxystore'))

        kor = result[:languages]['KOR']
        expect(kor[:title]).to be_nil
        expect(kor[:screenshots]).to be_nil
      end
    end
  end

  describe '.build_payload' do
    let(:base_metadata) do
      {
        icon_path: '/tmp/icon.png',
        languages: {
          'ENG' => {
            title: 'My App',
            short_description: 'Short',
            long_description: 'Long'
          },
          'FRA' => {
            title: 'Mon App',
            short_description: 'Courte',
            long_description: 'Longue'
          }
        }
      }
    end

    it 'puts the default language fields at the top level' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, 'icon_key_123', {})

      expect(payload[:contentId]).to eq('000007498732')
      expect(payload[:defaultLanguageCode]).to eq('ENG')
      expect(payload[:appTitle]).to eq('My App')
      expect(payload[:shortDescription]).to eq('Short')
      expect(payload[:longDescription]).to eq('Long')
      expect(payload[:iconKey]).to eq('icon_key_123')
    end

    it 'puts additional languages in addLanguage array' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, {})

      add_lang = payload[:addLanguage]
      expect(add_lang).to be_an(Array)
      expect(add_lang.length).to eq(1)

      fra = add_lang.first
      expect(fra[:languagecode]).to eq('FRA')
      expect(fra[:appTitle]).to eq('Mon App')
      expect(fra[:shortDescription]).to eq('Courte')
      expect(fra[:description]).to eq('Longue')
    end

    it 'omits addLanguage key when there is only one language' do
      single_lang_metadata = {
        icon_path: nil,
        languages: {
          'ENG' => { title: 'My App', short_description: 'Short', long_description: 'Long' }
        }
      }

      payload = action.build_payload('000007498732', 'ENG', single_lang_metadata, nil, {})

      expect(payload).not_to have_key(:addLanguage)
    end

    it 'omits top-level text fields when default language has no text' do
      empty_metadata = {
        icon_path: nil,
        languages: { 'ENG' => {} }
      }

      payload = action.build_payload('000007498732', 'ENG', empty_metadata, nil, {})

      expect(payload).not_to have_key(:appTitle)
      expect(payload).not_to have_key(:shortDescription)
      expect(payload).not_to have_key(:longDescription)
    end

    it 'attaches screenshot keys for the default language' do
      screenshot_keys = { 'ENG' => ['key1', 'key2'] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, screenshot_keys)

      expect(payload[:screenshots]).to eq([
                                            { screenshotPath: nil, screenshotKey: 'key1', reuseYn: false },
                                            { screenshotPath: nil, screenshotKey: 'key2', reuseYn: false }
                                          ])
    end

    it 'attaches screenshot keys for additional languages' do
      screenshot_keys = { 'FRA' => ['fra_key'] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, screenshot_keys)

      fra = payload[:addLanguage].find { |l| l[:languagecode] == 'FRA' }
      expect(fra[:screenshots]).to eq([
                                        { screenshotPath: nil, screenshotKey: 'fra_key', reuseYn: false }
                                      ])
    end

    it 'handles a missing default language gracefully (uses empty hash)' do
      payload = action.build_payload('000007498732', 'DEU', base_metadata, nil, {})

      # DEU is not in the metadata — should not raise, and top-level text fields absent
      expect(payload[:defaultLanguageCode]).to eq('DEU')
      expect(payload).not_to have_key(:appTitle)
      # Both ENG and FRA end up in addLanguage
      codes = payload[:addLanguage].map { |l| l[:languagecode] }
      expect(codes).to contain_exactly('ENG', 'FRA')
    end
  end

  describe 'run — metadata directory validation' do
    it 'raises an error when the galaxystore directory does not exist' do
      Dir.mktmpdir do |tmp|
        expect do
          action.run(
            access_token: 'token',
            service_account_id: 'svc_id',
            content_id: '000007498732',
            metadata_path: tmp
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /galaxy_store_app_info/)
      end
    end
  end
end
