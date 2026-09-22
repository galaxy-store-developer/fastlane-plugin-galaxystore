require 'fastlane/plugin/galaxystore'

# Verifies the descriptive metadata fastlane reads from every action
# (`fastlane action <name>`, docs generation, platform filtering).
describe 'Galaxy Store action metadata' do
  actions = [
    Fastlane::Actions::GalaxyStoreAppInfoAction,
    Fastlane::Actions::GalaxyStoreAppListAction,
    Fastlane::Actions::GalaxyStoreImportFromSupplyAction,
    Fastlane::Actions::GalaxyStorePublishAppAction,
    Fastlane::Actions::GalaxyStoreSetPublicationTypeAction,
    Fastlane::Actions::GalaxyStoreSetStagedRolloutAction,
    Fastlane::Actions::GalaxyStoreStagedRolloutAction,
    Fastlane::Actions::GalaxyStoreSubmitAppAction,
    Fastlane::Actions::GalaxyStoreUpdateStagedRolloutBinaryAction,
    Fastlane::Actions::GalaxyStoreUploadApkAction,
    Fastlane::Actions::GalaxyStoreUploadMetadataAction
  ]

  actions.each do |action|
    describe action.name.split('::').last do
      it 'has a non-empty description' do
        expect(action.description).to be_a(String)
        expect(action.description).not_to be_empty
      end

      it 'has non-empty details' do
        expect(action.details).to be_a(String)
        expect(action.details).not_to be_empty
      end

      it 'lists at least one author' do
        expect(action.authors).to be_an(Array)
        expect(action.authors).not_to be_empty
      end

      it 'describes its return value' do
        expect(action.return_value).to be_a(String)
        expect(action.return_value).not_to be_empty
      end

      it 'supports only the android platform' do
        expect(action.is_supported?(:android)).to be true
        expect(action.is_supported?(:ios)).to be false
      end

      it 'declares every option with a key and description' do
        action.available_options.each do |option|
          expect(option).to be_a(FastlaneCore::ConfigItem)
          expect(option.key).to be_a(Symbol)
          expect(option.description).not_to be_empty
        end
      end
    end
  end

  describe 'GalaxyStoreUploadApkAction.output' do
    it 'declares the GALAXY_STORE_BINARY_SEQ shared value' do
      output = Fastlane::Actions::GalaxyStoreUploadApkAction.output
      expect(output.map(&:first)).to eq(['GALAXY_STORE_BINARY_SEQ'])
      expect(output.first.last).not_to be_empty
    end
  end
end
