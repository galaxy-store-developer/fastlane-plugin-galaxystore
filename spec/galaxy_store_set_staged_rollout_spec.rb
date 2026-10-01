require 'fastlane/plugin/galaxystore'
require 'tmpdir'
require 'json'

describe Fastlane::Actions::GalaxyStoreSetStagedRolloutAction do
  let(:action) { described_class }
  let(:base_params) do
    {
      access_token: 'token',
      service_account_id: 'svc_id',
      content_id: '000007498732',
      app_status: 'SALE'
    }
  end

  def stub_client
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:set_staged_rollout_rate).and_return({ 'result' => 'ok' })
    end
  end

  describe 'run — ENABLE' do
    it 'raises when rollout_rate is missing' do
      stub_client
      expect do
        action.run(base_params.merge(action: 'ENABLE'))
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /rollout_rate is required/)
    end

    it 'sends function=ENABLE_ROLLOUT with the rollout rate and no countries' do
      client = stub_client
      expect(client).to receive(:set_staged_rollout_rate)
        .with('000007498732', 'ENABLE_ROLLOUT', 'SALE', rollout_rate: 25, countries: nil)
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(action: 'ENABLE', rollout_rate: 25))
    end

    it 'passes inline countries through to the client' do
      client = stub_client
      countries = [{ countryCode: 'USA', rolloutRate: 40 }]
      expect(client).to receive(:set_staged_rollout_rate)
        .with('000007498732', 'ENABLE_ROLLOUT', 'SALE', rollout_rate: 25, countries:)
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(action: 'ENABLE', rollout_rate: 25, countries:))
    end

    it 'reads countries from a JSON file when countries_json_path is provided' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'countries.json')
        countries_from_file = [{ 'countryCode' => 'USA', 'rolloutRate' => 40 }]
        File.write(path, JSON.generate(countries_from_file))

        client = stub_client
        expect(client).to receive(:set_staged_rollout_rate)
          .with('000007498732', 'ENABLE_ROLLOUT', 'SALE', rollout_rate: 25, countries: countries_from_file)
          .and_return({ 'result' => 'ok' })

        action.run(base_params.merge(action: 'ENABLE', rollout_rate: 25, countries_json_path: path))
      end
    end

    it 'prefers countries_json_path over inline countries when both are provided' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'countries.json')
        countries_from_file = [{ 'countryCode' => 'KOR', 'rolloutRate' => 45 }]
        File.write(path, JSON.generate(countries_from_file))

        client = stub_client
        expect(client).to receive(:set_staged_rollout_rate)
          .with('000007498732', 'ENABLE_ROLLOUT', 'SALE', rollout_rate: 25, countries: countries_from_file)
          .and_return({ 'result' => 'ok' })

        action.run(base_params.merge(
                     action: 'ENABLE',
                     rollout_rate: 25,
                     countries: [{ countryCode: 'USA', rolloutRate: 40 }],
                     countries_json_path: path
                   ))
      end
    end

    it 'raises when countries_json_path points to a missing file' do
      stub_client
      expect do
        action.run(base_params.merge(
                     action: 'ENABLE',
                     rollout_rate: 25,
                     countries_json_path: '/tmp/does_not_exist_xyz.json'
                   ))
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /not found/)
    end
  end

  describe 'run — DISABLE' do
    it 'sends function=DISABLE_ROLLOUT with no rate or countries' do
      client = stub_client
      expect(client).to receive(:set_staged_rollout_rate)
        .with('000007498732', 'DISABLE_ROLLOUT', 'SALE', rollout_rate: nil, countries: nil)
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(action: 'DISABLE'))
    end

    it 'does not require rollout_rate' do
      stub_client
      expect { action.run(base_params.merge(action: 'DISABLE')) }.not_to raise_error
    end
  end

  describe 'run — case handling' do
    it 'upcases a lowercase action before resolving the function' do
      client = stub_client
      expect(client).to receive(:set_staged_rollout_rate)
        .with('000007498732', 'ENABLE_ROLLOUT', 'SALE', rollout_rate: 25, countries: nil)

      action.run(base_params.merge(action: 'enable', rollout_rate: 25))
    end

    it 'upcases a lowercase app_status' do
      client = stub_client
      expect(client).to receive(:set_staged_rollout_rate)
        .with('000007498732', 'DISABLE_ROLLOUT', 'REGISTRATION', rollout_rate: nil, countries: nil)

      action.run(base_params.merge(action: 'DISABLE', app_status: 'registration'))
    end
  end

  describe 'ConfigItem validation' do
    let(:action_item) { action.available_options.find { |o| o.key == :action } }
    let(:app_status_item) { action.available_options.find { |o| o.key == :app_status } }
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects an action other than ENABLE or DISABLE' do
      expect do
        action_item.verify_block.call('PAUSE')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /ENABLE.*DISABLE/)
    end

    it 'accepts ENABLE and DISABLE (case-insensitive)' do
      %w[ENABLE enable DISABLE disable].each do |value|
        expect { action_item.verify_block.call(value) }.not_to raise_error
      end
    end

    it 'rejects an app_status other than SALE or REGISTRATION' do
      expect do
        app_status_item.verify_block.call('DRAFT')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /SALE.*REGISTRATION/)
    end

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end
  end
end
