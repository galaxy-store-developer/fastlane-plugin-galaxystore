require 'fastlane/plugin/galaxystore'
require 'tmpdir'
require 'fileutils'
require 'webrick'

describe Fastlane::Actions::GalaxyStoreAppInfoAction do
  let(:action) { described_class }

  def make_entry(lang: 'ENG', status: 'FOR_SALE', screenshots: [], add_languages: [], icon: nil)
    entry = {
      'contentStatus' => status,
      'defaultLanguageCode' => lang,
      'appTitle' => "Title #{lang}",
      'shortDescription' => "Short #{lang}",
      'longDescription' => "Long #{lang}",
      'screenshots' => screenshots,
      'addLanguage' => add_languages
    }
    entry['icon'] = icon if icon
    entry
  end

  describe '.write_metadata — directory cleanup' do
    it 'removes stale language directories from a previous call' do
      Dir.mktmpdir do |tmp|
        action.write_metadata([make_entry(lang: 'ENG')], tmp)

        eng_dir = File.join(tmp, 'galaxystore', 'ENG')
        expect(Dir.exist?(eng_dir)).to be true

        action.write_metadata([make_entry(lang: 'FRA')], tmp)

        expect(Dir.exist?(eng_dir)).to be false
        fra_dir = File.join(tmp, 'galaxystore', 'FRA')
        expect(Dir.exist?(fra_dir)).to be true
      end
    end

    it 'removes stale files when the same directory is rewritten' do
      Dir.mktmpdir do |tmp|
        gs_path = File.join(tmp, 'galaxystore')

        action.write_metadata([make_entry(lang: 'ENG')], tmp)
        extra_file = File.join(gs_path, 'ENG', 'extra.txt')
        File.write(extra_file, 'leftover')

        action.write_metadata([make_entry(lang: 'ENG')], tmp)

        expect(File.exist?(extra_file)).to be false
      end
    end
  end

  describe '.write_metadata — text files' do
    it 'writes title, short_description, and long_description for the default language' do
      Dir.mktmpdir do |tmp|
        action.write_metadata([make_entry(lang: 'ENG')], tmp)

        eng_dir = File.join(tmp, 'galaxystore', 'ENG')
        expect(File.read(File.join(eng_dir, 'title.txt'))).to eq('Title ENG')
        expect(File.read(File.join(eng_dir, 'short_description.txt'))).to eq('Short ENG')
        expect(File.read(File.join(eng_dir, 'long_description.txt'))).to eq('Long ENG')
      end
    end

    it 'writes additional language files' do
      Dir.mktmpdir do |tmp|
        add_lang = {
          'languagecode' => 'FRA',
          'appTitle' => 'Titre',
          'shortDescription' => 'Court',
          'description' => 'Longue'
        }
        action.write_metadata([make_entry(add_languages: [add_lang])], tmp)

        fra_dir = File.join(tmp, 'galaxystore', 'FRA')
        expect(File.read(File.join(fra_dir, 'title.txt'))).to eq('Titre')
        expect(File.read(File.join(fra_dir, 'short_description.txt'))).to eq('Court')
        expect(File.read(File.join(fra_dir, 'long_description.txt'))).to eq('Longue')
      end
    end

    it 'skips writing when no entry has a contentStatus' do
      Dir.mktmpdir do |tmp|
        entry = make_entry
        entry.delete('contentStatus')

        action.write_metadata([entry], tmp)

        gs_path = File.join(tmp, 'galaxystore')
        expect(Dir.exist?(gs_path)).to be true
        expect(Dir.children(gs_path)).to be_empty
      end
    end

    it 'prefers any non-FOR_SALE entry over FOR_SALE (covers in-progress statuses we may not know about)' do
      Dir.mktmpdir do |tmp|
        for_sale = make_entry(lang: 'ENG', status: 'FOR_SALE')
        for_sale['appTitle'] = 'Old Title'
        in_progress = make_entry(lang: 'ENG', status: 'UNDER_DEVICE_TEST')
        in_progress['appTitle'] = 'New Title'

        action.write_metadata([for_sale, in_progress], tmp)

        title = File.read(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))
        expect(title).to eq('New Title')
      end
    end

    it 'prefers REGISTERING over FOR_SALE' do
      Dir.mktmpdir do |tmp|
        for_sale = make_entry(lang: 'ENG', status: 'FOR_SALE')
        for_sale['appTitle'] = 'Old Title'
        registering = make_entry(lang: 'ENG', status: 'REGISTERING')
        registering['appTitle'] = 'New Title'

        action.write_metadata([for_sale, registering], tmp)

        title = File.read(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))
        expect(title).to eq('New Title')
      end
    end

    it 'prefers UPDATING over FOR_SALE' do
      Dir.mktmpdir do |tmp|
        for_sale = make_entry(lang: 'ENG', status: 'FOR_SALE')
        for_sale['appTitle'] = 'Old Title'
        updating = make_entry(lang: 'ENG', status: 'UPDATING')
        updating['appTitle'] = 'New Title'

        action.write_metadata([for_sale, updating], tmp)

        title = File.read(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))
        expect(title).to eq('New Title')
      end
    end

    it 'prefers READY_FOR_CHANGE over FOR_SALE' do
      Dir.mktmpdir do |tmp|
        for_sale = make_entry(lang: 'ENG', status: 'FOR_SALE')
        for_sale['appTitle'] = 'Old Title'
        ready = make_entry(lang: 'ENG', status: 'READY_FOR_CHANGE')
        ready['appTitle'] = 'New Title'

        action.write_metadata([for_sale, ready], tmp)

        title = File.read(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))
        expect(title).to eq('New Title')
      end
    end

    it 'writes new_feature.txt for the default language when newFeature is present' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG')
        entry['newFeature'] = 'Bug fixes and improvements'
        action.write_metadata([entry], tmp)

        path = File.join(tmp, 'galaxystore', 'ENG', 'new_feature.txt')
        expect(File.read(path)).to eq('Bug fixes and improvements')
      end
    end

    it 'writes new_feature.txt for additional languages independently' do
      Dir.mktmpdir do |tmp|
        add_lang = {
          'languagecode' => 'FRA',
          'appTitle' => 'Titre',
          'shortDescription' => 'Court',
          'description' => 'Longue',
          'newFeature' => 'Corrections'
        }
        action.write_metadata([make_entry(add_languages: [add_lang])], tmp)

        path = File.join(tmp, 'galaxystore', 'FRA', 'new_feature.txt')
        expect(File.read(path)).to eq('Corrections')
      end
    end

    it 'does not write new_feature.txt when newFeature is missing or empty' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG')
        entry['newFeature'] = ''
        action.write_metadata([entry], tmp)

        expect(File.exist?(File.join(tmp, 'galaxystore', 'ENG', 'new_feature.txt'))).to be false
      end
    end

    it 'writes youtube_url.txt at the top level when youTubeURL is present' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG')
        entry['youTubeURL'] = 'https://youtu.be/abc'
        action.write_metadata([entry], tmp)

        path = File.join(tmp, 'galaxystore', 'youtube_url.txt')
        expect(File.read(path)).to eq('https://youtu.be/abc')
      end
    end

    it 'skips youtube_url.txt when youTubeURL is empty' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG')
        entry['youTubeURL'] = ''
        action.write_metadata([entry], tmp)

        expect(File.exist?(File.join(tmp, 'galaxystore', 'youtube_url.txt'))).to be false
      end
    end
  end

  describe '.write_json' do
    it 'writes the full API response as formatted JSON' do
      Dir.mktmpdir do |tmp|
        gs_path = File.join(tmp, 'galaxystore')
        FileUtils.mkdir_p(gs_path)

        data = [{ 'key' => 'value' }]
        action.write_json(data, tmp)

        json_path = File.join(gs_path, 'app_info.json')
        expect(File.exist?(json_path)).to be true
        expect(JSON.parse(File.read(json_path))).to eq(data)
      end
    end
  end

  describe '.collect_screenshot_downloads' do
    it 'collects download entries for screenshots with URLs' do
      Dir.mktmpdir do |tmp|
        lang_dir = File.join(tmp, 'ENG')
        downloads = []
        screenshots = [
          { 'screenshotPath' => 'https://cdn.example.com/shots/1.png' },
          { 'screenshotPath' => 'https://cdn.example.com/shots/2.jpg' }
        ]

        action.collect_screenshot_downloads(screenshots, lang_dir, downloads)

        expect(downloads.length).to eq(2)
        expect(downloads[0][:dest]).to end_with('1.png')
        expect(downloads[1][:dest]).to end_with('2.jpg')
      end
    end

    it 'skips screenshots with nil URLs' do
      Dir.mktmpdir do |tmp|
        lang_dir = File.join(tmp, 'ENG')
        downloads = []
        screenshots = [
          { 'screenshotPath' => nil },
          { 'screenshotPath' => 'https://cdn.example.com/shots/1.png' }
        ]

        action.collect_screenshot_downloads(screenshots, lang_dir, downloads)

        expect(downloads.length).to eq(1)
      end
    end

    it 'defaults to .png when the URL has no extension' do
      Dir.mktmpdir do |tmp|
        lang_dir = File.join(tmp, 'ENG')
        downloads = []
        screenshots = [{ 'screenshotPath' => 'https://cdn.example.com/image' }]

        action.collect_screenshot_downloads(screenshots, lang_dir, downloads)

        expect(downloads.first[:dest]).to end_with('1.png')
      end
    end
  end

  describe '.download_files' do
    before(:all) do
      @server = WEBrick::HTTPServer.new(Port: 0, Logger: WEBrick::Log.new('/dev/null'), AccessLog: [])
      @port = @server.config[:Port]

      @server.mount_proc('/image1.png') { |_req, res| res.body = 'pixel_data_1' }
      @server.mount_proc('/image2.png') { |_req, res| res.body = 'pixel_data_2' }
      @server.mount_proc('/icon.png') { |_req, res| res.body = 'icon_data' }
      @server.mount_proc('/redirect') do |_req, res|
        res.status = 302
        res['Location'] = "http://localhost:#{@port}/image1.png"
      end

      @server_thread = Thread.new { @server.start }
    end

    after(:all) do
      @server.shutdown
      @server_thread.join
    end

    it 'downloads multiple files from the same host on a single connection' do
      Dir.mktmpdir do |tmp|
        downloads = [
          { url: "http://localhost:#{@port}/image1.png", dest: File.join(tmp, '1.png') },
          { url: "http://localhost:#{@port}/image2.png", dest: File.join(tmp, '2.png') }
        ]

        action.download_files(downloads)

        expect(File.binread(File.join(tmp, '1.png'))).to eq('pixel_data_1')
        expect(File.binread(File.join(tmp, '2.png'))).to eq('pixel_data_2')
      end
    end

    it 'follows redirects' do
      Dir.mktmpdir do |tmp|
        downloads = [
          { url: "http://localhost:#{@port}/redirect", dest: File.join(tmp, 'redirected.png') }
        ]

        action.download_files(downloads)

        expect(File.binread(File.join(tmp, 'redirected.png'))).to eq('pixel_data_1')
      end
    end

    it 'handles empty download list without error' do
      expect { action.download_files([]) }.not_to raise_error
    end

    it 'continues downloading other files when one fails' do
      Dir.mktmpdir do |tmp|
        downloads = [
          { url: "http://localhost:#{@port}/nonexistent", dest: File.join(tmp, 'missing.png') },
          { url: "http://localhost:#{@port}/image1.png", dest: File.join(tmp, '1.png') }
        ]

        action.download_files(downloads)

        expect(File.binread(File.join(tmp, '1.png'))).to eq('pixel_data_1')
      end
    end
  end
end
