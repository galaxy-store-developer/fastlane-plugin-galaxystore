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

  describe 'run' do
    it 'fetches app info, writes metadata and JSON, and returns the API response' do
      Dir.mktmpdir do |tmp|
        app_info = [make_entry]
        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).with('svc_id', 'token').and_return(client)
        expect(client).to receive(:get_app_info).with('000007498732').and_return(app_info)

        result = action.run(
          access_token: 'token',
          service_account_id: 'svc_id',
          content_id: '000007498732',
          metadata_path: tmp
        )

        expect(result).to eq(app_info)
        expect(File.read(File.join(tmp, 'galaxystore', 'ENG', 'title.txt'))).to eq('Title ENG')
        expect(JSON.parse(File.read(File.join(tmp, 'galaxystore', 'app_info.json')))).to eq(app_info)
      end
    end
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

    it 'skips screenshots whose URL has a non-image extension' do
      Dir.mktmpdir do |tmp|
        lang_dir = File.join(tmp, 'ENG')
        downloads = []
        screenshots = [
          { 'screenshotPath' => 'https://cdn.example.com/shots/1.php' },
          { 'screenshotPath' => 'https://cdn.example.com/shots/2.png' }
        ]

        allow(Fastlane::UI).to receive(:important)
        expect(Fastlane::UI).to receive(:important).with(/unsupported image extension '.php'/)

        action.collect_screenshot_downloads(screenshots, lang_dir, downloads)

        expect(downloads.length).to eq(1)
        expect(downloads.first[:dest]).to end_with('2.png')
      end
    end
  end

  describe '.image_extension' do
    it 'returns allowlisted extensions unchanged' do
      %w[.png .jpg .jpeg .gif .webp].each do |ext|
        expect(action.image_extension("https://cdn.example.com/img#{ext}")).to eq(ext)
      end
    end

    it 'normalizes uppercase extensions to lowercase' do
      expect(action.image_extension('https://cdn.example.com/IMG.PNG')).to eq('.png')
    end

    it 'defaults to .png when the URL has no extension' do
      expect(action.image_extension('https://cdn.example.com/img')).to eq('.png')
    end

    it 'ignores the query string when determining the extension' do
      expect(action.image_extension('https://cdn.example.com/icon.png?path=../../../../tmp/malicious.sh')).to eq('.png')
    end

    it 'returns nil and warns for extensions outside the allowlist' do
      expect(Fastlane::UI).to receive(:important).with(/unsupported image extension '.sh'/)
      expect(action.image_extension('https://cdn.example.com/icon.sh')).to be_nil
    end
  end

  describe '.write_metadata — icon and hero image extension allowlist' do
    it 'queues icon and hero image downloads with allowlisted extensions' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG', icon: 'https://cdn.example.com/icon.jpg')
        entry['heroImage'] = 'https://cdn.example.com/hero.webp'

        queued = nil
        allow(action).to receive(:download_files) { |downloads| queued = downloads }

        action.write_metadata([entry], tmp)

        dests = queued.map { |d| File.basename(d[:dest]) }
        expect(dests).to contain_exactly('icon.jpg', 'hero_image.webp')
      end
    end

    it 'skips icon and hero image downloads with non-image extensions' do
      Dir.mktmpdir do |tmp|
        entry = make_entry(lang: 'ENG', icon: 'https://cdn.example.com/icon.php')
        entry['heroImage'] = 'https://cdn.example.com/hero.exe'

        queued = nil
        allow(action).to receive(:download_files) { |downloads| queued = downloads }
        allow(Fastlane::UI).to receive(:important)

        action.write_metadata([entry], tmp)

        expect(queued).to be_empty
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

    it 'blocks redirects to private IPs' do
      Dir.mktmpdir do |tmp|
        downloads = [
          { url: "http://localhost:#{@port}/redirect", dest: File.join(tmp, 'redirected.png') }
        ]

        action.download_files(downloads)

        expect(File.exist?(File.join(tmp, 'redirected.png'))).to be false
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

    it 'reports a connection failure without raising when the host is unreachable' do
      Dir.mktmpdir do |tmp|
        # Port 1 (tcpmux) is never listening locally, so the connection is refused immediately.
        downloads = [{ url: 'http://127.0.0.1:1/image.png', dest: File.join(tmp, 'x.png') }]

        expect(Fastlane::UI).to receive(:important).with(/Connection failed for 127\.0\.0\.1/)
        expect(Fastlane::UI).to receive(:message).with(/Downloaded 1 file/)

        action.download_files(downloads)

        expect(File.exist?(File.join(tmp, 'x.png'))).to be false
      end
    end

    it 'follows a validated redirect on the shared connection' do
      Dir.mktmpdir do |tmp|
        allow(action).to receive(:validate_redirect_url!)
        downloads = [{ url: "http://localhost:#{@port}/redirect", dest: File.join(tmp, 'redirected.png') }]

        action.download_files(downloads)

        expect(File.binread(File.join(tmp, 'redirected.png'))).to eq('pixel_data_1')
        expect(action).to have_received(:validate_redirect_url!).with("http://localhost:#{@port}/image1.png")
      end
    end

    it 'opens a fresh connection when a job targets a different host than the shared connection' do
      Dir.mktmpdir do |tmp|
        dest = File.join(tmp, 'other.png')
        http = instance_double(Net::HTTP, address: 'cdn.example.com')

        expect(action).to receive(:download_single).with("http://localhost:#{@port}/image1.png", dest, 5)

        action.download_with_connection(http, "http://localhost:#{@port}/image1.png", dest)
      end
    end

    it 'raises when the redirect limit is exhausted on the shared connection' do
      http = instance_double(Net::HTTP, address: 'localhost')

      expect do
        action.download_with_connection(http, 'http://localhost/loop', 'dest.png', 0)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Too many redirects/)
    end
  end

  describe '.download_single' do
    before(:all) do
      @server = WEBrick::HTTPServer.new(Port: 0, Logger: WEBrick::Log.new('/dev/null'), AccessLog: [])
      @port = @server.config[:Port]

      @server.mount_proc('/icon.png') { |_req, res| res.body = 'icon_data' }
      @server.mount_proc('/redirect') do |_req, res|
        res.status = 302
        res['Location'] = "http://localhost:#{@port}/icon.png"
      end

      @server_thread = Thread.new { @server.start }
    end

    after(:all) do
      @server.shutdown
      @server_thread.join
    end

    it 'downloads a file over its own connection' do
      Dir.mktmpdir do |tmp|
        dest = File.join(tmp, 'icon.png')

        action.download_single("http://localhost:#{@port}/icon.png", dest)

        expect(File.binread(dest)).to eq('icon_data')
      end
    end

    it 'validates and follows a redirect' do
      Dir.mktmpdir do |tmp|
        dest = File.join(tmp, 'icon.png')
        allow(action).to receive(:validate_redirect_url!)

        action.download_single("http://localhost:#{@port}/redirect", dest)

        expect(File.binread(dest)).to eq('icon_data')
        expect(action).to have_received(:validate_redirect_url!).with("http://localhost:#{@port}/icon.png")
      end
    end

    it 'raises when the redirect limit is exhausted' do
      expect do
        action.download_single('http://localhost/loop', 'dest.png', 0)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Too many redirects/)
    end
  end

  describe '.validate_redirect_url!' do
    it 'rejects HTTP redirect targets' do
      expect do
        action.validate_redirect_url!('http://cdn.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /HTTPS required/)
    end

    it 'rejects redirect to 127.0.0.0/8' do
      allow(Resolv).to receive(:getaddresses).and_return(['127.0.0.1'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect to 10.0.0.0/8' do
      allow(Resolv).to receive(:getaddresses).and_return(['10.1.2.3'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect to 172.16.0.0/12' do
      allow(Resolv).to receive(:getaddresses).and_return(['172.16.0.1'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect to 192.168.0.0/16' do
      allow(Resolv).to receive(:getaddresses).and_return(['192.168.1.1'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect to 169.254.0.0/16 (link-local / cloud metadata)' do
      allow(Resolv).to receive(:getaddresses).and_return(['169.254.169.254'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect to ::1' do
      allow(Resolv).to receive(:getaddresses).and_return(['::1'])
      expect do
        action.validate_redirect_url!('https://evil.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /private address/)
    end

    it 'rejects redirect when DNS resolution fails' do
      allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError.new('no address'))
      expect do
        action.validate_redirect_url!('https://nonexistent.example.com/image.png')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /cannot resolve/)
    end

    it 'allows redirect to a public HTTPS URL' do
      allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
      expect do
        action.validate_redirect_url!('https://cdn.example.com/image.png')
      end.not_to raise_error
    end
  end
end
