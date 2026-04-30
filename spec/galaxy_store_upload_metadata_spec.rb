require 'digest'
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

    it 'omits iconKey when icon_key is nil' do
      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, {})

      expect(payload).not_to have_key(:iconKey)
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

    it 'attaches screenshot entries for the default language' do
      entries = { 'ENG' => [
        { screenshotPath: nil, screenshotKey: 'key1', reuseYn: false },
        { screenshotPath: nil, screenshotKey: 'key2', reuseYn: false }
      ] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, entries)

      expect(payload[:screenshots]).to eq(entries['ENG'])
    end

    it 'attaches screenshot entries for additional languages' do
      entries = { 'FRA' => [
        { screenshotPath: nil, screenshotKey: 'fra_key', reuseYn: false }
      ] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, entries)

      fra = payload[:addLanguage].find { |l| l[:languagecode] == 'FRA' }
      expect(fra[:screenshots]).to eq(entries['FRA'])
    end

    it 'supports mixed reuse and new screenshot entries' do
      entries = { 'ENG' => [
        { screenshotPath: 'https://cdn.example.com/old.png', screenshotKey: nil, reuseYn: true },
        { screenshotPath: nil, screenshotKey: 'new_key', reuseYn: false }
      ] }

      payload = action.build_payload('000007498732', 'ENG', base_metadata, nil, entries)

      expect(payload[:screenshots]).to eq(entries['ENG'])
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

  describe '.load_checksums' do
    it 'returns an empty hash when no checksums file exists' do
      Dir.mktmpdir do |tmp|
        expect(action.load_checksums(tmp)).to eq({})
      end
    end

    it 'parses the checksums file when present' do
      Dir.mktmpdir do |tmp|
        manifest = { 'icon.png' => { 'md5' => 'abc123', 'remote_url' => 'https://cdn.example.com/icon.png' } }
        File.write(File.join(tmp, '.checksums.json'), manifest.to_json)

        result = action.load_checksums(tmp)
        expect(result['icon.png']['md5']).to eq('abc123')
      end
    end
  end

  describe '.file_changed?' do
    it 'returns true when file is not in the manifest' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'new.png')
        File.binwrite(path, 'data')

        expect(action.file_changed?(path, tmp, {})).to be true
      end
    end

    it 'returns false when file MD5 matches the manifest' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'icon.png')
        File.binwrite(path, 'pixel_data')
        md5 = Digest::MD5.file(path).hexdigest

        checksums = { 'icon.png' => { 'md5' => md5, 'remote_url' => 'https://cdn.example.com/icon.png' } }
        expect(action.file_changed?(path, tmp, checksums)).to be false
      end
    end

    it 'returns true when file MD5 differs from the manifest' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'icon.png')
        File.binwrite(path, 'modified_data')

        checksums = { 'icon.png' => { 'md5' => 'stale_checksum', 'remote_url' => 'https://cdn.example.com/icon.png' } }
        expect(action.file_changed?(path, tmp, checksums)).to be true
      end
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
                  '{"body":{"errorMsg":"The length of the short description is invalid. (20 ~ 240 bytes)"}}'

      expect(Fastlane::UI).to receive(:error).with(/Per-language breakdown for short_description/)
      expect(Fastlane::UI).to receive(:error).with(/ENG: 23 bytes/)
      expect(Fastlane::UI).to receive(:error).with(/FRA: 5 bytes/)

      action.diagnose_api_error(error_msg, metadata)
    end

    it 'logs per-language breakdown for title errors' do
      error_msg = '[POST /seller/contentUpdate] Request failed with status 400: ' \
                  '{"body":{"errorMsg":"The title is invalid."}}'

      expect(Fastlane::UI).to receive(:error).with(/Per-language breakdown for title/)
      expect(Fastlane::UI).to receive(:error).with(/ENG:/)
      expect(Fastlane::UI).to receive(:error).with(/FRA:/)

      action.diagnose_api_error(error_msg, metadata)
    end

    it 'does nothing when the error does not match a known field' do
      error_msg = '[POST /seller/contentUpdate] Request failed with status 400: ' \
                  '{"body":{"errorMsg":"Something unrelated went wrong"}}'

      expect(Fastlane::UI).not_to receive(:error)

      action.diagnose_api_error(error_msg, metadata)
    end

    it 'handles unparseable JSON gracefully' do
      expect { action.diagnose_api_error('not json at all', metadata) }.not_to raise_error
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
