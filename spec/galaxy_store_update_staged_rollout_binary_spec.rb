require 'fastlane/plugin/upload_galaxystore'

describe Fastlane::Actions::GalaxyStoreUpdateStagedRolloutBinaryAction do
  let(:action) { described_class }
  let(:base_params) do
    { access_token: 'token', service_account_id: 'svc_id', content_id: '000007498732', binary_seq: '15' }
  end

  def stub_client
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:update_staged_rollout_binary).and_return({ 'result' => 'ok' })
    end
  end

  describe 'run' do
    it 'calls update_staged_rollout_binary with function=ADD' do
      client = stub_client
      expect(client).to receive(:update_staged_rollout_binary)
        .with('000007498732', 'ADD', '15')
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(function: 'ADD'))
    end

    it 'calls update_staged_rollout_binary with function=REMOVE' do
      client = stub_client
      expect(client).to receive(:update_staged_rollout_binary)
        .with('000007498732', 'REMOVE', '15')
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(function: 'REMOVE'))
    end

    it 'upcases a lowercase function value before passing it through' do
      client = stub_client
      expect(client).to receive(:update_staged_rollout_binary)
        .with('000007498732', 'ADD', '15')
        .and_return({ 'result' => 'ok' })

      action.run(base_params.merge(function: 'add'))
    end

    it 'returns the result from the client' do
      stub_client
      expect(action.run(base_params.merge(function: 'ADD'))).to eq({ 'result' => 'ok' })
    end
  end

  describe 'ConfigItem validation' do
    let(:function_item) { action.available_options.find { |o| o.key == :function } }
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects a function other than ADD or REMOVE' do
      expect do
        function_item.verify_block.call('DELETE')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /ADD.*REMOVE/)
    end

    it 'accepts ADD and REMOVE (case-insensitive)' do
      %w[ADD add REMOVE remove].each do |value|
        expect { function_item.verify_block.call(value) }.not_to raise_error
      end
    end

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end
  end
end
