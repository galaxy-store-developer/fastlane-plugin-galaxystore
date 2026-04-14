require 'fastlane/plugin/upload_galaxystore'
require 'tmpdir'

describe Fastlane::Actions::GalaxyStoreUploadApkAction do
  let(:action) { described_class }

  describe 'input validation' do
    it 'raises an error when the file does not exist' do
      expect do
        action.run(
          access_token: 'token',
          service_account_id: 'svc_id',
          content_id: '000007498732',
          apk_path: '/nonexistent/app.apk'
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /File not found/)
    end

    it 'raises an error for unsupported file extensions' do
      Dir.mktmpdir do |tmp|
        zip_path = File.join(tmp, 'app.zip')
        File.write(zip_path, 'fake zip content')

        expect do
          action.run(
            access_token: 'token',
            service_account_id: 'svc_id',
            content_id: '000007498732',
            apk_path: zip_path
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Unsupported file type/)
      end
    end

    it 'accepts .apk files' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'fake apk content')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'key123' })
        allow(client).to receive(:add_binary).and_return({})

        expect do
          action.run(
            access_token: 'token',
            service_account_id: 'svc_id',
            content_id: '000007498732',
            apk_path: apk_path
          )
        end.not_to raise_error
      end
    end

    it 'accepts .aab files' do
      Dir.mktmpdir do |tmp|
        aab_path = File.join(tmp, 'app.aab')
        File.write(aab_path, 'fake aab content')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'key456' })
        allow(client).to receive(:add_binary).and_return({})

        expect do
          action.run(
            access_token: 'token',
            service_account_id: 'svc_id',
            content_id: '000007498732',
            apk_path: aab_path
          )
        end.not_to raise_error
      end
    end
  end

  describe 'upload flow' do
    it 'calls create_update, upload_file, and add_binary in sequence' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'fake apk content')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new)
          .with('svc_id', 'token')
          .and_return(client)

        expect(client).to receive(:create_update).with('000007498732').ordered
        expect(client).to receive(:upload_file).with(apk_path).ordered.and_return({ 'fileKey' => 'key123' })
        expect(client).to receive(:add_binary).with('000007498732', 'key123').ordered.and_return({ 'result' => 'ok' })

        result = action.run(
          access_token: 'token',
          service_account_id: 'svc_id',
          content_id: '000007498732',
          apk_path: apk_path
        )

        expect(result).to eq({ 'result' => 'ok' })
      end
    end

    it 'returns the result from add_binary' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'fk' })
        allow(client).to receive(:add_binary).and_return({ 'binarySeq' => '42' })

        result = action.run(
          access_token: 'token',
          service_account_id: 'svc_id',
          content_id: '000007498732',
          apk_path: apk_path
        )

        expect(result['binarySeq']).to eq('42')
      end
    end
  end

  describe 'ConfigItem validation for content_id' do
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end

    it 'rejects a content_id that is 12 letters' do
      expect do
        content_id_item.verify_block.call('ABCDEFGHIJKL')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end

    it 'rejects a content_id that is 13 digits' do
      expect do
        content_id_item.verify_block.call('0000074987321')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end

    it 'accepts a valid 12-digit content_id' do
      expect do
        content_id_item.verify_block.call('000007498732')
      end.not_to raise_error
    end
  end
end
