require 'fastlane/plugin/galaxystore'
require 'tmpdir'
require 'fileutils'
require 'json'

describe Fastlane::Actions::GalaxyStoreAppListAction do
  let(:action) { described_class }
  let(:base_params) { { access_token: 'token', service_account_id: 'svc_id' } }
  let(:app_list) do
    [
      { 'contentId' => '000001234567', 'appTitle' => 'App One' },
      { 'contentId' => '000007654321', 'appTitle' => 'App Two' }
    ]
  end

  def stub_client(list = app_list)
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:get_app_list).and_return(list)
    end
  end

  describe 'run' do
    it 'returns the app list from the client' do
      stub_client
      expect(action.run(base_params)).to eq(app_list)
    end

    it 'does not write to disk when output_path is omitted' do
      stub_client
      expect(File).not_to receive(:write)
      action.run(base_params)
    end

    it 'writes the app list as JSON when output_path is provided' do
      stub_client
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'apps.json')
        action.run(base_params.merge(output_path: path))

        expect(JSON.parse(File.read(path))).to eq(app_list)
      end
    end

    it 'creates intermediate directories for output_path' do
      stub_client
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'nested', 'subdir', 'apps.json')
        action.run(base_params.merge(output_path: path))

        expect(File.exist?(path)).to be true
      end
    end
  end
end
