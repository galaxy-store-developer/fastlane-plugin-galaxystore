require 'fastlane/plugin/galaxystore'

describe Fastlane::Actions::GalaxyStoreSetPublicationTypeAction do
  let(:action) { described_class }
  let(:base_params) do
    { access_token: 'token', service_account_id: 'svc_id', content_id: '000007498732' }
  end
  let(:stub_client) do
    instance_double(Fastlane::Helper::GalaxyStoreClient).tap do |client|
      allow(Fastlane::Helper::GalaxyStoreClient).to receive(:new).and_return(client)
      allow(client).to receive(:update_content_metadata).and_return({})
    end
  end

  describe 'run' do
    context 'publication type 01 (automatic)' do
      it 'sends publicationType 01' do
        stub_client
        expect(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:update_content_metadata)
          .with({ contentId: '000007498732', publicationType: '01' })
          .and_return({})

        action.run(base_params.merge(publication_type: '01'))
      end
    end

    context 'publication type 02 (scheduled)' do
      it 'sends publicationType and startPublicationDate' do
        stub_client
        expect(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:update_content_metadata)
          .with({ contentId: '000007498732', publicationType: '02', startPublicationDate: '2026-06-01 09:00:00' })
          .and_return({})

        action.run(base_params.merge(
                     publication_type: '02',
                     start_publication_date: '2026-06-01 09:00:00'
                   ))
      end

      it 'raises when start_publication_date is missing' do
        expect do
          action.run(base_params.merge(publication_type: '02'))
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /start_publication_date is required/)
      end
    end

    context 'publication type 03 (manual)' do
      it 'sends publicationType 03 without a date' do
        stub_client
        expect(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:update_content_metadata)
          .with({ contentId: '000007498732', publicationType: '03' })
          .and_return({})

        action.run(base_params.merge(publication_type: '03'))
      end
    end

    it 'warns when start_publication_date is set but publication_type is not 02' do
      stub_client
      expect(Fastlane::UI).to receive(:important).with(/date will be ignored/)

      action.run(base_params.merge(
                   publication_type: '01',
                   start_publication_date: '2026-06-01 09:00:00'
                 ))
    end

    it 'returns the result from update_content_metadata' do
      stub_client
      allow(Fastlane::Helper::GalaxyStoreClient.new('', '')).to receive(:update_content_metadata)
        .and_return({ 'result' => 'ok' })

      result = action.run(base_params)
      expect(result).to eq({ 'result' => 'ok' })
    end
  end

  describe 'ConfigItem validation' do
    let(:publication_type_item) { action.available_options.find { |o| o.key == :publication_type } }
    let(:date_item) { action.available_options.find { |o| o.key == :start_publication_date } }
    let(:content_id_item) { action.available_options.find { |o| o.key == :content_id } }

    it 'rejects a publication_type other than 01, 02, 03' do
      expect do
        publication_type_item.verify_block.call('04')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /must be '01', '02', or '03'/)
    end

    it 'accepts 01, 02, and 03 as publication_type' do
      %w[01 02 03].each do |type|
        expect { publication_type_item.verify_block.call(type) }.not_to raise_error
      end
    end

    it 'rejects a start_publication_date with the wrong format' do
      expect do
        date_item.verify_block.call('2026/06/01 09:00:00')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /yyyy-MM-dd HH:mm:ss/)
    end

    it 'rejects a start_publication_date with a date only (no time)' do
      expect do
        date_item.verify_block.call('2026-06-01')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /yyyy-MM-dd HH:mm:ss/)
    end

    it 'accepts a correctly formatted start_publication_date' do
      expect { date_item.verify_block.call('2026-06-01 09:00:00') }.not_to raise_error
    end

    it 'rejects a content_id that is not 12 digits' do
      expect do
        content_id_item.verify_block.call('123')
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /12-digit/)
    end
  end
end
