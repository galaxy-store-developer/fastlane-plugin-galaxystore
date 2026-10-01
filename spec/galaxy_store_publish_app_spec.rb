require 'fastlane/plugin/galaxystore'

describe Fastlane::Actions::GalaxyStorePublishAppAction do
  let(:action) { described_class }
  let(:params) do
    { access_token: 'token', service_account_id: 'svc_id', content_id: '000001234567' }
  end

  describe 'run' do
    it 'calls update_content_status with FOR_SALE and returns the result' do
      client = instance_double(Fastlane::Helper::GalaxyStoreClient)
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new)
        .with('svc_id', 'token')
        .and_return(client)
      expect(client).to receive(:update_content_status)
        .with('000001234567', 'FOR_SALE')
        .and_return({ 'result' => 'ok' })

      result = action.run(params)
      expect(result).to eq({ 'result' => 'ok' })
    end
  end

  describe 'ConfigItem validation for content_id' do
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end

    it 'accepts a valid 12-digit content_id' do
      expect do
        content_id_item.verify_block.call('000001234567')
      end.not_to raise_error
    end
  end
end
