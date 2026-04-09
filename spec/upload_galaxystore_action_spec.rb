describe Fastlane::Actions::UploadGalaxystoreAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The upload_galaxystore plugin is working!")

      Fastlane::Actions::UploadGalaxystoreAction.run(nil)
    end
  end
end
