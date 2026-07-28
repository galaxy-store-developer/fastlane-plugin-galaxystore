require 'fastlane/plugin/galaxystore'

describe Fastlane::Helper::GalaxyStoreClient do
  let(:client) { described_class.new('svc_id', 'token') }

  describe '#format_error' do
    def format(body)
      client.send(:format_error, 'POST', '/seller/contentUpdate', '400', body)
    end

    it 'surfaces errorCode and errorMsg from the body wrapper' do
      body = '{"body":{"errorCode":"3001","errorMsg":"The title is invalid."}}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400 (errorCode 3001): The title is invalid.'
      )
    end

    it 'surfaces resultCode and resultMessage from the body wrapper' do
      body = '{"body":{"resultCode":"5021","resultMessage":"This binary is already in use."},' \
             '"message":"Request failed with status code 400","from":"seller"}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400 (errorCode 5021): This binary is already in use.'
      )
    end

    it 'prefers body.resultMessage over the top-level generic message' do
      body = '{"body":{"resultMessage":"Specific cause"},"message":"Request failed with status code 400"}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400: Specific cause'
      )
    end

    it 'surfaces errorMsg only when errorCode is missing' do
      body = '{"body":{"errorMsg":"The title is invalid."}}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400: The title is invalid.'
      )
    end

    it 'accepts top-level errorCode/errorMsg without the body wrapper' do
      body = '{"errorCode":"4002","errorMsg":"Bad request"}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400 (errorCode 4002): Bad request'
      )
    end

    it 'falls back to message field when errorMsg is absent' do
      body = '{"message":"Unauthorized scope"}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400: Unauthorized scope'
      )
    end

    it 'falls back to the raw body when JSON cannot be parsed' do
      body = '<html>503 Service Unavailable</html>'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400: <html>503 Service Unavailable</html>'
      )
    end

    it 'falls back to the raw body when JSON has no recognized error fields' do
      body = '{"foo":"bar"}'
      expect(format(body)).to eq(
        '[POST /seller/contentUpdate] Request failed with status 400: {"foo":"bar"}'
      )
    end
  end
end
