require 'fastlane/plugin/upload_galaxystore'
require 'tmpdir'
require 'fileutils'

describe Fastlane::Actions::GalaxyStoreImportFromSupplyAction do
  let(:action) { described_class }

  # Build a minimal Supply-style metadata/android directory inside a tmp dir.
  # Returns the metadata_path (parent of 'android').
  def build_supply_dir(base, languages: {}, icon_lang: nil)
    android_path = File.join(base, 'android')
    FileUtils.mkdir_p(android_path)

    languages.each do |bcp47, files|
      lang_dir = File.join(android_path, bcp47)
      FileUtils.mkdir_p(lang_dir)
      FileUtils.mkdir_p(File.join(lang_dir, 'images'))

      files.each do |filename, content|
        if filename.start_with?('images/')
          dest = File.join(lang_dir, filename)
          FileUtils.mkdir_p(File.dirname(dest))
          File.write(dest, content)
        else
          File.write(File.join(lang_dir, filename), content)
        end
      end
    end

    if icon_lang
      icon_dir = File.join(android_path, icon_lang, 'images')
      FileUtils.mkdir_p(icon_dir)
      File.write(File.join(icon_dir, 'icon.png'), 'fake_icon_data')
    end

    base
  end

  describe 'file mapping' do
    it 'converts full_description.txt to long_description.txt' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'en' => {
              'title.txt' => 'My App',
              'short_description.txt' => 'Short desc',
              'full_description.txt' => 'Long description here'
            }
          }
        )

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        dest = File.join(tmp, 'galaxystore', 'ENG', 'long_description.txt')
        expect(File.exist?(dest)).to be true
        expect(File.read(dest)).to eq('Long description here')
      end
    end

    it 'copies title.txt and short_description.txt unchanged' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'fr' => {
              'title.txt' => 'Mon App',
              'short_description.txt' => 'Courte description',
              'full_description.txt' => 'Longue description'
            }
          }
        )

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        dest_dir = File.join(tmp, 'galaxystore', 'FRA')
        expect(File.read(File.join(dest_dir, 'title.txt'))).to eq('Mon App')
        expect(File.read(File.join(dest_dir, 'short_description.txt'))).to eq('Courte description')
      end
    end
  end

  describe 'language mapping' do
    it 'maps BCP-47 directories to Galaxy Store language codes' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'en' => { 'title.txt' => 'English' },
            'de' => { 'title.txt' => 'Deutsch' },
            'ko' => { 'title.txt' => '한국어' }
          }
        )

        result = action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        expect(result.keys).to contain_exactly('ENG', 'DEU', 'KOR')
        expect(File.exist?(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))).to be true
        expect(File.exist?(File.join(tmp, 'galaxystore', 'DEU', 'title.txt'))).to be true
        expect(File.exist?(File.join(tmp, 'galaxystore', 'KOR', 'title.txt'))).to be true
      end
    end

    it 'skips unmapped languages with a warning' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'en'  => { 'title.txt' => 'English' },
            'fil' => { 'title.txt' => 'Filipino' }  # not supported
          }
        )

        allow(Fastlane::UI).to receive(:important)
        expect(Fastlane::UI).to receive(:important).with(/No Galaxy Store language mapping found for 'fil'/)

        result = action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        expect(result.keys).to contain_exactly('ENG')
        expect(File.exist?(File.join(tmp, 'galaxystore', 'ENG'))).to be true
        expect(File.exist?(File.join(tmp, 'galaxystore', 'FIL'))).to be false
      end
    end

    it 'resolves many-to-one collisions using language_priority overrides' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'es'    => { 'title.txt' => 'Spanish neutral' },
            'es-419' => { 'title.txt' => 'Spanish latam' }
          }
        )

        allow(Fastlane::UI).to receive(:important)
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for SPA/)

        result = action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: { 'SPA' => 'es-419' }
        )

        expect(result['SPA']).to eq('es-419')
        title = File.read(File.join(tmp, 'galaxystore', 'SPA', 'title.txt'))
        expect(title).to eq('Spanish latam')
      end
    end
  end

  describe 'icon handling' do
    it 'copies the icon from the default language directory' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: { 'en' => { 'title.txt' => 'App' } },
          icon_lang: 'en'
        )

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        expect(File.exist?(File.join(tmp, 'galaxystore', 'icon.png'))).to be true
      end
    end

    it 'warns when the default language has no icon' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: { 'en' => { 'title.txt' => 'App' } }
          # no icon_lang
        )

        allow(Fastlane::UI).to receive(:important)
        expect(Fastlane::UI).to receive(:important).with(/No icon found at/)

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )
      end
    end

    it 'warns when the default language code is not present in the metadata' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: { 'de' => { 'title.txt' => 'App' } }
        )

        allow(Fastlane::UI).to receive(:important)
        expect(Fastlane::UI).to receive(:important).with(/Default language 'ENG' not found/)

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )
      end
    end
  end

  describe 'screenshot handling' do
    it 'copies phoneScreenshots renaming them 1.png, 2.png, ...' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'en' => {
              'title.txt' => 'App',
              'images/phoneScreenshots/screen_a.png' => 'data_a',
              'images/phoneScreenshots/screen_b.png' => 'data_b'
            }
          }
        )

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        screenshots_dir = File.join(tmp, 'galaxystore', 'ENG', 'screenshots')
        expect(Dir.exist?(screenshots_dir)).to be true

        files = Dir.glob(File.join(screenshots_dir, '*')).map { |f| File.basename(f) }.sort
        expect(files).to eq(['1.png', '2.png'])
      end
    end

    it 'skips screenshots directory when none are present' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: { 'en' => { 'title.txt' => 'App' } }
        )

        action.run(
          metadata_path: tmp,
          default_language_code: 'ENG',
          language_priority: {}
        )

        screenshots_dir = File.join(tmp, 'galaxystore', 'ENG', 'screenshots')
        expect(Dir.exist?(screenshots_dir)).to be false
      end
    end
  end

  describe 'error handling' do
    it 'raises an error when the Supply android directory does not exist' do
      Dir.mktmpdir do |tmp|
        expect do
          action.run(
            metadata_path: tmp,
            default_language_code: 'ENG',
            language_priority: {}
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Supply metadata directory not found/)
      end
    end

    it 'raises an error when the android directory contains no language subdirectories' do
      Dir.mktmpdir do |tmp|
        FileUtils.mkdir_p(File.join(tmp, 'android'))

        expect do
          action.run(
            metadata_path: tmp,
            default_language_code: 'ENG',
            language_priority: {}
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /No language directories found/)
      end
    end

    it 'raises an error when all languages are unmapped' do
      Dir.mktmpdir do |tmp|
        build_supply_dir(tmp,
          languages: {
            'fil' => { 'title.txt' => 'Filipino' },
            'sw'  => { 'title.txt' => 'Swahili' }
          }
        )

        allow(Fastlane::UI).to receive(:important)

        expect do
          action.run(
            metadata_path: tmp,
            default_language_code: 'ENG',
            language_priority: {}
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /No mappable languages found/)
      end
    end
  end
end
