require 'fastlane/plugin/galaxystore'
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
      payload = action.build_payload('000007498732', 'ENG', base_metadata, 'icon_key_123', nil, {})

      expect(payload[:contentId]).to eq('000007498732')
      expect(payload[:defaultLanguageCode]).to eq('ENG')
      expect(payload[:appTitle]).to eq('My App')
      expect(payload[:shortDescription]).to eq('Short')
      expect(payload[:longDescription]).to eq('Long')
      expect(payload[:iconKey]).to eq('icon_key_123')
    end

    it 'omits iconKey when icon_key is nil' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, nil, {})

      expect(payload).not_to have_key(:iconKey)
    end

    it 'includes heroImageKey when hero_image_key is set' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, 'hero_key_456', {})

      expect(payload[:heroImageKey]).to eq('hero_key_456')
    end

    it 'omits heroImageKey when hero_image_key is nil' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, nil, {})

      expect(payload).not_to have_key(:heroImageKey)
    end

    it 'includes youTubeURL when present and non-empty' do
      metadata = base_metadata.merge(youtube_url: 'https://youtube.com/watch?v=abc')
      payload = action.build_payload('000007498732', 'ENG', metadata, nil, nil, {})

      expect(payload[:youTubeURL]).to eq('https://youtube.com/watch?v=abc')
    end

    it 'omits youTubeURL when blank' do
      metadata = base_metadata.merge(youtube_url: '')
      payload = action.build_payload('000007498732', 'ENG', metadata, nil, nil, {})

      expect(payload).not_to have_key(:youTubeURL)
    end

    it 'includes newFeature for the default language at the top level' do
      metadata = {
        icon_path: nil,
        languages: { 'ENG' => { title: 'T', short_description: 'S', long_description: 'L', new_feature: 'Bug fixes' } }
      }
      payload = action.build_payload('000007498732', 'ENG', metadata, nil, nil, {})

      expect(payload[:newFeature]).to eq('Bug fixes')
    end

    it 'includes newFeature in addLanguage entries' do
      metadata = {
        icon_path: nil,
        languages: {
          'ENG' => { title: 'T' },
          'FRA' => { title: 'T', new_feature: 'Corrections' }
        }
      }
      payload = action.build_payload('000007498732', 'ENG', metadata, nil, nil, {})

      fra = payload[:addLanguage].find { |l| l[:languagecode] == 'FRA' }
      expect(fra[:newFeature]).to eq('Corrections')
    end

    it 'puts additional languages in addLanguage array' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, nil, {})

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

      payload = action.build_payload('000007498732', 'ENG', single_lang_metadata, nil, nil, {})

      expect(payload).not_to have_key(:addLanguage)
    end

    it 'omits top-level text fields when default language has no text' do
      empty_metadata = {
        icon_path: nil,
        languages: { 'ENG' => {} }
      }

      payload = action.build_payload('000007498732', 'ENG', empty_metadata, nil, nil, {})

      expect(payload).not_to have_key(:appTitle)
      expect(payload).not_to have_key(:shortDescription)
      expect(payload).not_to have_key(:longDescription)
    end

    it 'attaches screenshot entries for the default language' do
      entries = { 'ENG' => [
        { screenshotPath: nil, screenshotKey: 'key1', reuseYn: false },
        { screenshotPath: nil, screenshotKey: 'key2', reuseYn: false }
      ] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, nil, entries)

      expect(payload[:screenshots]).to eq(entries['ENG'])
    end

    it 'attaches screenshot entries for additional languages' do
      entries = { 'FRA' => [
        { screenshotPath: nil, screenshotKey: 'fra_key', reuseYn: false }
      ] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, nil, entries)

      fra = payload[:addLanguage].find { |l| l[:languagecode] == 'FRA' }
      expect(fra[:screenshots]).to eq(entries['FRA'])
    end

    it 'handles a missing default language gracefully (uses empty hash)' do
      payload = action.build_payload('000007498732', 'DEU', base_metadata, nil, nil, {})

      # DEU is not in the metadata — should not raise, and top-level text fields absent
      expect(payload[:defaultLanguageCode]).to eq('DEU')
      expect(payload).not_to have_key(:appTitle)
      # Both ENG and FRA end up in addLanguage
      codes = payload[:addLanguage].map { |l| l[:languagecode] }
      expect(codes).to contain_exactly('ENG', 'FRA')
    end
  end

  describe '.validate_metadata' do
    it 'passes when short_description is within range' do
      metadata = { languages: { 'ENG' => { short_description: 'A' * 20 } } }
      expect { action.validate_metadata(metadata) }.not_to raise_error
    end

    it 'passes when short_description is at the upper bound' do
      metadata = { languages: { 'ENG' => { short_description: 'A' * 240 } } }
      expect { action.validate_metadata(metadata) }.not_to raise_error
    end

    it 'raises when short_description is too short' do
      metadata = { languages: { 'ENG' => { short_description: 'Short' } } }
      expect { action.validate_metadata(metadata) }.to raise_error(
        FastlaneCore::Interface::FastlaneError, /ENG: short_description is 5 bytes/
      )
    end

    it 'raises when short_description is too long' do
      metadata = { languages: { 'ENG' => { short_description: 'A' * 241 } } }
      expect { action.validate_metadata(metadata) }.to raise_error(
        FastlaneCore::Interface::FastlaneError, /ENG: short_description is 241 bytes/
      )
    end

    it 'reports all failing languages in one error' do
      metadata = {
        languages: {
          'ENG' => { short_description: 'OK description text!!' },
          'FRA' => { short_description: 'Trop court' },
          'DEU' => { short_description: 'Zu kurz' }
        }
      }
      expect { action.validate_metadata(metadata) }.to raise_error(
        FastlaneCore::Interface::FastlaneError, /FRA.*DEU/m
      )
    end

    it 'skips languages without a short_description' do
      metadata = { languages: { 'ENG' => { title: 'My App' } } }
      expect { action.validate_metadata(metadata) }.not_to raise_error
    end

    it 'counts multi-byte characters by bytesize' do
      metadata = { languages: { 'JPN' => { short_description: "あ" * 7 } } }
      expect { action.validate_metadata(metadata) }.not_to raise_error
    end
  end

  describe '.diagnose_api_error' do
    let(:metadata) do
      {
        languages: {
          'ENG' => { short_description: 'Valid description text!', title: 'My App' },
          'FRA' => { short_description: 'Court', title: 'Mon App' }
        }
      }
    end

    it 'logs per-language breakdown for short description errors' do
      error_msg = '[POST /seller/contentUpdate] Request failed with status 400: ' \
                  'The length of the short description is invalid. (20 ~ 240 bytes)'

      expect(Fastlane::UI).to receive(:error).with(/Per-language breakdown for short_description/)
      expect(Fastlane::UI).to receive(:error).with(/ENG: 23 bytes/)
      expect(Fastlane::UI).to receive(:error).with(/FRA: 5 bytes/)

      action.diagnose_api_error(error_msg, metadata)
    end

    it 'logs per-language breakdown for title errors' do
      error_msg = '[POST /seller/contentUpdate] Request failed with status 400 (errorCode 3001): The title is invalid.'

      expect(Fastlane::UI).to receive(:error).with(/Per-language breakdown for title/)
      expect(Fastlane::UI).to receive(:error).with(/ENG:/)
      expect(Fastlane::UI).to receive(:error).with(/FRA:/)

      action.diagnose_api_error(error_msg, metadata)
    end

    it 'does nothing when the error does not match a known field' do
      error_msg = '[POST /seller/contentUpdate] Request failed with status 400: Something unrelated went wrong'

      expect(Fastlane::UI).not_to receive(:error)

      action.diagnose_api_error(error_msg, metadata)
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

  describe 'run — upload flow' do
    let(:client) { instance_double(Fastlane::Helper::GalaxyStoreClient) }
    let(:params) do
      { access_token: 'token', service_account_id: 'svc_id', content_id: '000007498732', default_language_code: 'ENG' }
    end

    before do
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).with('svc_id', 'token').and_return(client)
    end

    it 'uploads icon and screenshots, then submits the assembled payload' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp,
                              icon: true,
                              languages: {
                                'ENG' => {
                                  title: 'My App',
                                  short_description: 'A great app for everyone',
                                  screenshots: ['1.png', '2.png']
                                },
                                'FRA' => { title: 'Mon App' }
                              })

        allow(client).to receive(:upload_file) do |path|
          { 'fileKey' => "key-#{File.basename(path)}" }
        end
        expect(client).to receive(:update_content_metadata) do |payload|
          expect(payload[:contentId]).to eq('000007498732')
          expect(payload[:iconKey]).to eq('key-icon.png')
          expect(payload).not_to have_key(:heroImageKey)
          expect(payload[:appTitle]).to eq('My App')
          expect(payload[:screenshots].map { |s| s[:screenshotKey] }).to eq(['key-1.png', 'key-2.png'])
          expect(payload[:addLanguage]).to eq([{ languagecode: 'FRA', appTitle: 'Mon App' }])
          { 'result' => 'ok' }
        end

        result = action.run(params.merge(metadata_path: tmp, upload_hero_image: false))

        expect(result).to eq({ 'result' => 'ok' })
        expect(client).to have_received(:upload_file).exactly(3).times
      end
    end

    it 'uploads the hero image only when upload_hero_image is enabled' do
      Dir.mktmpdir do |tmp|
        gs_path = build_galaxystore_dir(tmp, languages: { 'ENG' => { title: 'My App' } })
        File.write(File.join(gs_path, 'hero_image.png'), 'hero')

        expect(client).to receive(:upload_file).with(end_with('hero_image.png')).and_return({ 'fileKey' => 'hero-key' })
        expect(client).to receive(:update_content_metadata)
          .with(hash_including(heroImageKey: 'hero-key'))
          .and_return({})

        action.run(params.merge(metadata_path: tmp, upload_hero_image: true))
      end
    end

    it 'skips the hero image when upload_hero_image is disabled' do
      Dir.mktmpdir do |tmp|
        gs_path = build_galaxystore_dir(tmp, languages: { 'ENG' => { title: 'My App' } })
        File.write(File.join(gs_path, 'hero_image.png'), 'hero')

        expect(client).not_to receive(:upload_file)
        expect(client).to receive(:update_content_metadata) do |payload|
          expect(payload).not_to have_key(:heroImageKey)
          {}
        end

        action.run(params.merge(metadata_path: tmp, upload_hero_image: false))
      end
    end

    it 'prints a per-language diagnosis and re-raises when the API rejects with a 400' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp, languages: { 'ENG' => { short_description: 'Valid description text!' } })

        allow(client).to receive(:update_content_metadata) do
          raise FastlaneCore::Interface::FastlaneError.new,
                '[POST /seller/contentUpdate] Request failed with status 400: The length of the short description is invalid.'
        end
        expect(Fastlane::UI).to receive(:error).with(/Per-language breakdown for short_description/)
        expect(Fastlane::UI).to receive(:error).with(/ENG: 23 bytes/)

        expect do
          action.run(params.merge(metadata_path: tmp, upload_hero_image: false))
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /status 400/)
      end
    end

    it 're-raises non-400 API errors without a diagnosis' do
      Dir.mktmpdir do |tmp|
        build_galaxystore_dir(tmp, languages: { 'ENG' => { title: 'My App' } })

        allow(client).to receive(:update_content_metadata) do
          raise FastlaneCore::Interface::FastlaneError.new, '[POST /seller/contentUpdate] Access denied (403).'
        end
        expect(Fastlane::UI).not_to receive(:error)

        expect do
          action.run(params.merge(metadata_path: tmp, upload_hero_image: false))
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /403/)
      end
    end
  end

  describe '.upload_icon' do
    it 'returns nil when there is no icon' do
      expect(action.upload_icon(nil, nil)).to be_nil
    end
  end

  describe '.upload_hero_image' do
    it 'returns nil when there is no hero image' do
      expect(action.upload_hero_image(nil, nil)).to be_nil
    end
  end
end
