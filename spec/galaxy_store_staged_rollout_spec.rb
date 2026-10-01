require 'fastlane/plugin/galaxystore'

describe Fastlane::Actions::GalaxyStoreStagedRolloutAction do
  let(:action) { described_class }
  let(:base_params) do
    { access_token: 'token', service_account_id: 'svc_id', content_id: '000007498732', app_status: 'SALE' }
  end

  def stub_client(binaries_response:, rate_response: nil)
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:get_staged_rollout_binaries).and_return(binaries_response)
      allow(client).to receive(:get_staged_rollout_rate).and_return(rate_response) if rate_response
    end
  end

  describe 'run' do
    it 'returns nil when no binaries are found' do
      stub_client(binaries_response: { 'data' => { 'binaries' => [] } })
      expect(action.run(base_params)).to be_nil
    end

    it 'returns nil when the data key is missing entirely' do
      stub_client(binaries_response: {})
      expect(action.run(base_params)).to be_nil
    end

    it 'returns binaries with rollout_rate=nil when no binary has rollout enabled' do
      binaries = [
        { 'seq' => '15', 'versionName' => '1.0', 'rolloutStatus' => 'DISABLED' },
        { 'seq' => '16', 'versionName' => '2.0', 'rolloutStatus' => 'DISABLED' }
      ]
      client = stub_client(binaries_response: { 'data' => { 'binaries' => binaries } })
      expect(client).not_to receive(:get_staged_rollout_rate)

      result = action.run(base_params)
      expect(result).to eq({ binaries:, rollout_rate: nil })
    end

    it 'fetches the rate and returns full data when a binary has rollout enabled' do
      binaries = [{ 'seq' => '15', 'versionName' => '1.0', 'rolloutStatus' => 'ENABLED' }]
      rate_data = { 'rolloutRate' => 25, 'countries' => nil }
      stub_client(
        binaries_response: { 'data' => { 'binaries' => binaries } },
        rate_response: { 'data' => rate_data }
      )

      result = action.run(base_params)
      expect(result).to eq({ binaries:, rollout_rate: rate_data })
    end

    it 'logs per-country rates when the rate response includes countries' do
      binaries = [{ 'seq' => '15', 'versionName' => '1.0', 'rolloutStatus' => 'ENABLED' }]
      countries = [
        { 'countryCode' => 'USA', 'rolloutRate' => 40 },
        { 'countryCode' => 'KOR', 'rolloutRate' => 45 }
      ]
      stub_client(
        binaries_response: { 'data' => { 'binaries' => binaries } },
        rate_response: { 'data' => { 'rolloutRate' => 25, 'countries' => countries } }
      )

      expect(Fastlane::UI).to receive(:success).with(/USA: 40%/)
      expect(Fastlane::UI).to receive(:success).with(/KOR: 45%/)
      allow(Fastlane::UI).to receive(:success)

      action.run(base_params)
    end

    it 'upcases a lowercase app_status before passing it to the client' do
      client = stub_client(binaries_response: { 'data' => { 'binaries' => [] } })
      expect(client).to receive(:get_staged_rollout_binaries)
        .with('000007498732', 'SALE')

      action.run(base_params.merge(app_status: 'sale'))
    end
  end

  describe 'ConfigItem validation' do
    let(:app_status_item) { action.available_options.find { |o| o.key == :app_status } }
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects an app_status other than SALE or REGISTRATION' do
      expect do
        app_status_item.verify_block.call('DRAFT')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /SALE.*REGISTRATION/)
    end

    it 'accepts SALE and REGISTRATION (case-insensitive)' do
      %w[SALE sale REGISTRATION registration].each do |value|
        expect { app_status_item.verify_block.call(value) }.not_to raise_error
      end
    end

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end
  end
end
