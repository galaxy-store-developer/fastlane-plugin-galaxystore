require 'fastlane/plugin/galaxystore'
require 'tmpdir'

describe Fastlane::Actions::GalaxyStoreUploadApkAction do
  let(:action) { described_class }

  # Helpers for setting/clearing lane context shared values
  def with_lane_context(values)
    values.each { |k, v| Fastlane::Actions.lane_context[k] = v }
    yield
  ensure
    values.each_key { |k| Fastlane::Actions.lane_context.delete(k) }
  end

  let(:base_params) do
    { access_token: 'token', service_account_id: 'svc_id', content_id: '000001234567', gms: 'N' }
  end

  let(:stub_client) do
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:create_update)
      allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'key123' })
      allow(client).to receive(:add_binary).and_return({ 'resultCode' => '0000', 'data' => { 'binarySeq' => '1' } })
    end
  end

  before { Fastlane::Actions.lane_context.delete(Fastlane::Actions::SharedValues::GALAXY_STORE_BINARY_SEQ) }

  describe 'input validation' do
    it 'raises an error when the file does not exist' do
      expect do
        action.run(
          access_token: 'token',
          service_account_id: 'svc_id',
          content_id: '000001234567',
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
            content_id: '000001234567',
            apk_path: zip_path
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Unsupported file type/)
      end
    end

    it 'accepts .apk files' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'fake apk content')
        stub_client

        expect { action.run(base_params.merge(apk_path:)) }.not_to raise_error
      end
    end

    it 'accepts .aab files' do
      Dir.mktmpdir do |tmp|
        aab_path = File.join(tmp, 'app.aab')
        File.write(aab_path, 'fake aab content')
        stub_client

        expect { action.run(base_params.merge(apk_path: aab_path)) }.not_to raise_error
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

        expect(client).to receive(:create_update).with('000001234567').ordered
        expect(client).to receive(:upload_file).with(apk_path).ordered.and_return({ 'fileKey' => 'key123' })
        expect(client).to receive(:add_binary).with('000001234567', 'key123', gms: 'N').ordered
                                              .and_return({ 'resultCode' => '0000', 'data' => { 'binarySeq' => '7' } })

        action.run(base_params.merge(apk_path:))
      end
    end

    it 'returns the binarySeq from the add_binary response' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'fk' })
        allow(client).to receive(:add_binary).and_return({ 'data' => { 'binarySeq' => '42' } })

        result = action.run(base_params.merge(apk_path:))

        expect(result).to eq('42')
      end
    end

    it 'writes the binarySeq to lane context' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')
        stub_client

        action.run(base_params.merge(apk_path:))

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::GALAXY_STORE_BINARY_SEQ]).to eq('1')
      end
    end

    it 'returns nil and skips lane context when add_binary does not include a binarySeq' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'fk' })
        allow(client).to receive(:add_binary).and_return({ 'resultCode' => '0000' })

        result = action.run(base_params.merge(apk_path:))

        expect(result).to be_nil
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::GALAXY_STORE_BINARY_SEQ]).to be_nil
      end
    end

    it 'forwards an uppercased gms value to add_binary when specified' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')

        client = instance_double(Fastlane::Helper::GalaxyStoreClient)
        allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
        allow(client).to receive(:create_update)
        allow(client).to receive(:upload_file).and_return({ 'fileKey' => 'fk' })

        expect(client).to receive(:add_binary).with('000001234567', 'fk', gms: 'Y').and_return({})

        action.run(base_params.merge(apk_path:, gms: 'y'))
      end
    end
  end

  describe 'lane context fallback' do
    it 'raises when apk_path is omitted and lane context is empty' do
      expect do
        action.run(base_params)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{No APK/AAB path provided})
    end

    it 'uses GRADLE_AAB_OUTPUT_PATH when apk_path is not set' do
      Dir.mktmpdir do |tmp|
        aab_path = File.join(tmp, 'app.aab')
        File.write(aab_path, 'data')
        stub_client

        with_lane_context(Fastlane::Actions::SharedValues::GRADLE_AAB_OUTPUT_PATH => aab_path) do
          expect { action.run(base_params) }.not_to raise_error
        end
      end
    end

    it 'uses GRADLE_ALL_AAB_OUTPUT_PATHS when there is exactly one entry' do
      Dir.mktmpdir do |tmp|
        aab_path = File.join(tmp, 'app.aab')
        File.write(aab_path, 'data')
        stub_client

        with_lane_context(Fastlane::Actions::SharedValues::GRADLE_ALL_AAB_OUTPUT_PATHS => [aab_path]) do
          expect { action.run(base_params) }.not_to raise_error
        end
      end
    end

    it 'ignores GRADLE_ALL_AAB_OUTPUT_PATHS when there are multiple entries and falls back to GRADLE_AAB_OUTPUT_PATH' do
      Dir.mktmpdir do |tmp|
        aab1 = File.join(tmp, 'app1.aab')
        aab2 = File.join(tmp, 'app2.aab')
        single = File.join(tmp, 'single.aab')
        [aab1, aab2, single].each { |f| File.write(f, 'data') }
        stub_client

        expect(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:upload_file).with(single).and_return({ 'fileKey' => 'k' })

        with_lane_context(
          Fastlane::Actions::SharedValues::GRADLE_ALL_AAB_OUTPUT_PATHS => [aab1, aab2],
          Fastlane::Actions::SharedValues::GRADLE_AAB_OUTPUT_PATH => single
        ) do
          action.run(base_params)
        end
      end
    end

    it 'prefers AAB over APK when both are in lane context' do
      Dir.mktmpdir do |tmp|
        aab_path = File.join(tmp, 'app.aab')
        apk_path = File.join(tmp, 'app.apk')
        [aab_path, apk_path].each { |f| File.write(f, 'data') }
        stub_client

        expect(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:upload_file).with(aab_path).and_return({ 'fileKey' => 'k' })

        with_lane_context(
          Fastlane::Actions::SharedValues::GRADLE_AAB_OUTPUT_PATH => aab_path,
          Fastlane::Actions::SharedValues::GRADLE_APK_OUTPUT_PATH => apk_path
        ) do
          action.run(base_params)
        end
      end
    end

    it 'falls back to GRADLE_APK_OUTPUT_PATH when no AAB is in lane context' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')
        stub_client

        with_lane_context(Fastlane::Actions::SharedValues::GRADLE_APK_OUTPUT_PATH => apk_path) do
          expect { action.run(base_params) }.not_to raise_error
        end
      end
    end

    it 'uses GRADLE_ALL_APK_OUTPUT_PATHS when there is exactly one entry and no AAB' do
      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.write(apk_path, 'data')
        stub_client

        with_lane_context(Fastlane::Actions::SharedValues::GRADLE_ALL_APK_OUTPUT_PATHS => [apk_path]) do
          expect { action.run(base_params) }.not_to raise_error
        end
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
        content_id_item.verify_block.call('0000012345678')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end

    it 'accepts a valid 12-digit content_id' do
      expect do
        content_id_item.verify_block.call('000001234567')
      end.not_to raise_error
    end
  end

  describe 'ConfigItem validation for gms' do
    let(:gms_item) { action.available_options.find { |o| o.key == :gms } }

    it "accepts 'Y'" do
      expect { gms_item.verify_block.call('Y') }.not_to raise_error
    end

    it "accepts 'N'" do
      expect { gms_item.verify_block.call('N') }.not_to raise_error
    end

    it 'accepts lowercase values' do
      expect { gms_item.verify_block.call('y') }.not_to raise_error
    end

    it 'rejects other values' do
      expect { gms_item.verify_block.call('Maybe') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /gms must be/)
    end
  end
end
