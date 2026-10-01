require 'fastlane/plugin/galaxystore'
require 'tmpdir'

describe Fastlane::Helper::GalaxyStoreClient do
  let(:client) { described_class.new('svc_id', 'token') }

  # Builds a minimal Net::HTTPResponse stand-in.
  def fake_response(code, body = nil, headers = {})
    response = instance_double(Net::HTTPResponse, code: code.to_s, message: 'STATUS', body:)
    allow(response).to receive(:[]) { |key| headers[key] }
    response
  end

  # Stubs Net::HTTP.start so each call yields a connection that returns the next
  # response in the queue (the last response is repeated). Returns the list of
  # captured (host, request) pairs for assertions.
  def stub_http(*responses)
    calls = []
    queue = responses.dup
    allow(Net::HTTP).to receive(:start) do |host, _port, _opts, &block|
      http = double('http')
      allow(http).to receive(:request) do |request|
        calls << [host, request]
        queue.length > 1 ? queue.shift : queue.first
      end
      block.call(http)
    end
    calls
  end

  describe 'authentication headers' do
    it 'sends bearer token, service account ID, and client source on every request' do
      calls = stub_http(fake_response(200, '[]'))

      client.get_app_list

      _host, request = calls.first
      expect(request['Authorization']).to eq('Bearer token')
      expect(request['service-account-id']).to eq('svc_id')
      expect(request['X-Client-Source']).to eq('fastlane-plugin-galaxystore')
    end
  end

  describe '#get_app_list' do
    it 'issues GET /seller/contentList and parses the JSON body' do
      calls = stub_http(fake_response(200, '[{"contentId":"1"}]'))

      result = client.get_app_list

      host, request = calls.first
      expect(host).to eq('devapi.samsungapps.com')
      expect(request.method).to eq('GET')
      expect(request.path).to eq('/seller/contentList')
      expect(result).to eq([{ 'contentId' => '1' }])
    end
  end

  describe '#get_app_info' do
    it 'issues GET /seller/contentInfo with contentId as a query parameter' do
      calls = stub_http(fake_response(200, '[]'))

      client.get_app_info('000001234567')

      _host, request = calls.first
      expect(request.path).to eq('/seller/contentInfo?contentId=000001234567')
    end
  end

  describe '#create_upload_session_id' do
    it 'issues POST /seller/createUploadSessionId without a body and returns the sessionId' do
      calls = stub_http(fake_response(200, '{"sessionId":"sess-123"}'))

      expect(client.create_upload_session_id).to eq('sess-123')

      _host, request = calls.first
      expect(request.method).to eq('POST')
      expect(request.path).to eq('/seller/createUploadSessionId')
      expect(request.body).to be_nil
      expect(request['Content-Type']).to be_nil
    end
  end

  describe '#upload_file' do
    it 'creates a session, then posts a multipart body to the seller upload host' do
      calls = stub_http(fake_response(200, '{"sessionId":"sess-123"}'), fake_response(200, '{"fileKey":"key-1"}'))

      Dir.mktmpdir do |tmp|
        apk_path = File.join(tmp, 'app.apk')
        File.binwrite(apk_path, 'binary-content')

        result = client.upload_file(apk_path)

        expect(result).to eq({ 'fileKey' => 'key-1' })
        expect(calls.length).to eq(2)

        host, request = calls.last
        expect(host).to eq('seller.samsungapps.com')
        expect(request.path).to eq('/galaxyapi/fileUpload')
        expect(request['Content-Type']).to match(%r{\Amultipart/form-data; boundary=----RubyFormBoundary[0-9a-f]{32}\z})

        boundary = request['Content-Type'].split('boundary=').last
        body = request.body
        expect(body).to include("--#{boundary}\r\n")
        expect(body).to include('Content-Disposition: form-data; name="file"; filename="app.apk"')
        expect(body).to include('Content-Type: application/vnd.android.package-archive')
        expect(body).to include('binary-content')
        expect(body).to include('Content-Disposition: form-data; name="sessionId"')
        expect(body).to include('sess-123')
        expect(body).to end_with("--#{boundary}--\r\n")
      end
    end
  end

  describe 'JSON POST endpoints' do
    def last_json_post(calls)
      _host, request = calls.last
      expect(request.method).to eq('POST')
      expect(request['Content-Type']).to eq('application/json')
      [request.path, JSON.parse(request.body)]
    end

    it '#submit_app posts the contentId to /seller/contentSubmit' do
      calls = stub_http(fake_response(200, '{}'))
      client.submit_app('000001234567')
      expect(last_json_post(calls)).to eq(['/seller/contentSubmit', { 'contentId' => '000001234567' }])
    end

    it '#update_content_status posts contentId and contentStatus' do
      calls = stub_http(fake_response(200, '{}'))
      client.update_content_status('000001234567', 'FOR_SALE')
      expect(last_json_post(calls)).to eq(
        ['/seller/contentStatusUpdate', { 'contentId' => '000001234567', 'contentStatus' => 'FOR_SALE' }]
      )
    end

    it '#create_update posts the contentId to /seller/contentUpdate' do
      calls = stub_http(fake_response(200, '{}'))
      client.create_update('000001234567')
      expect(last_json_post(calls)).to eq(['/seller/contentUpdate', { 'contentId' => '000001234567' }])
    end

    it '#update_content_metadata posts the payload as-is to /seller/contentUpdate' do
      calls = stub_http(fake_response(200, '{}'))
      client.update_content_metadata({ contentId: '1', appTitle: 'Title' })
      expect(last_json_post(calls)).to eq(['/seller/contentUpdate', { 'contentId' => '1', 'appTitle' => 'Title' }])
    end

    it '#add_binary posts contentId, gms, and filekey to /seller/v2/content/binary' do
      calls = stub_http(fake_response(200, '{}'))
      client.add_binary('000001234567', 'key-1', gms: 'Y')
      expect(last_json_post(calls)).to eq(
        ['/seller/v2/content/binary', { 'contentId' => '000001234567', 'gms' => 'Y', 'filekey' => 'key-1' }]
      )
    end
  end

  describe 'staged rollout endpoints' do
    def last_json_put(calls)
      _host, request = calls.last
      expect(request.method).to eq('PUT')
      expect(request['Content-Type']).to eq('application/json')
      [request.path, JSON.parse(request.body)]
    end

    it '#update_staged_rollout_binary PUTs contentId, function, and binarySeq as a string' do
      calls = stub_http(fake_response(200, '{}'))
      client.update_staged_rollout_binary('000001234567', 'ADD', 42)
      expect(last_json_put(calls)).to eq(
        ['/seller/v2/content/stagedRolloutBinary',
         { 'contentId' => '000001234567', 'function' => 'ADD', 'binarySeq' => '42' }]
      )
    end

    it '#set_staged_rollout_rate omits rolloutRate and countries when not given' do
      calls = stub_http(fake_response(200, '{}'))
      client.set_staged_rollout_rate('000001234567', 'DISABLE', 'FOR_SALE')
      expect(last_json_put(calls)).to eq(
        ['/seller/v2/content/stagedRolloutRate',
         { 'contentId' => '000001234567', 'function' => 'DISABLE', 'appStatus' => 'FOR_SALE' }]
      )
    end

    it '#set_staged_rollout_rate includes rolloutRate and countries when given' do
      calls = stub_http(fake_response(200, '{}'))
      countries = [{ code: 'USA', rolloutRate: 10 }]
      client.set_staged_rollout_rate('000001234567', 'ENABLE', 'FOR_SALE', rollout_rate: 25, countries:)
      _path, body = last_json_put(calls)
      expect(body['rolloutRate']).to eq(25)
      expect(body['countries']).to eq([{ 'code' => 'USA', 'rolloutRate' => 10 }])
    end

    it '#set_staged_rollout_rate omits countries when the list is empty' do
      calls = stub_http(fake_response(200, '{}'))
      client.set_staged_rollout_rate('000001234567', 'ENABLE', 'FOR_SALE', rollout_rate: 25, countries: [])
      _path, body = last_json_put(calls)
      expect(body).not_to have_key('countries')
    end

    it '#get_staged_rollout_binaries GETs with contentId and appStatus query params' do
      calls = stub_http(fake_response(200, '{}'))
      client.get_staged_rollout_binaries('000001234567', 'FOR_SALE')
      _host, request = calls.last
      expect(request.method).to eq('GET')
      expect(request.path).to eq('/seller/v2/content/stagedRolloutBinary?contentId=000001234567&appStatus=FOR_SALE')
    end

    it '#get_staged_rollout_rate GETs with contentId and appStatus query params' do
      calls = stub_http(fake_response(200, '{}'))
      client.get_staged_rollout_rate('000001234567', 'FOR_SALE')
      _host, request = calls.last
      expect(request.method).to eq('GET')
      expect(request.path).to eq('/seller/v2/content/stagedRolloutRate?contentId=000001234567&appStatus=FOR_SALE')
    end
  end

  describe 'response handling' do
    it 'returns nil for a 204 No Content response' do
      stub_http(fake_response(204))
      expect(client.get_app_list).to be_nil
    end

    it 'raises an authentication error for 401' do
      stub_http(fake_response(401, ''))
      expect { client.get_app_list }.to raise_error(
        FastlaneCore::Interface::FastlaneError, %r{\[GET /seller/contentList\] Authentication failed \(401\)}
      )
    end

    it 'raises an access denied error for 403' do
      stub_http(fake_response(403, ''))
      expect { client.get_app_list }.to raise_error(FastlaneCore::Interface::FastlaneError, /Access denied \(403\)/)
    end

    it 'raises a not found error for 404' do
      stub_http(fake_response(404, ''))
      expect { client.get_app_info('1') }.to raise_error(FastlaneCore::Interface::FastlaneError, /Not found \(404\)/)
    end

    it 'raises a formatted error with the API errorMsg for other failure codes' do
      stub_http(fake_response(400, '{"body":{"errorCode":"3001","errorMsg":"The title is invalid."}}'))
      expect { client.submit_app('1') }.to raise_error(
        FastlaneCore::Interface::FastlaneError,
        '[POST /seller/contentSubmit] Request failed with status 400 (errorCode 3001): The title is invalid.'
      )
    end
  end

  describe 'async (303) polling' do
    before { allow(client).to receive(:sleep) }

    it 'follows a relative Location header and returns the parsed body once the poll returns 200' do
      calls = stub_http(
        fake_response(303, '', { 'Location' => '/seller/asyncResult/abc' }),
        fake_response(200, '{"done":true}')
      )

      expect(client.submit_app('1')).to eq({ 'done' => true })

      _host, poll_request = calls.last
      expect(poll_request.method).to eq('GET')
      expect(poll_request.path).to eq('/seller/asyncResult/abc')
      expect(poll_request['Authorization']).to eq('Bearer token')
    end

    it 'follows an absolute Location header' do
      calls = stub_http(
        fake_response(303, '', { 'Location' => 'https://devapi.samsungapps.com/seller/asyncResult/xyz' }),
        fake_response(200, '{}')
      )

      client.submit_app('1')

      host, poll_request = calls.last
      expect(host).to eq('devapi.samsungapps.com')
      expect(poll_request.path).to eq('/seller/asyncResult/xyz')
    end

    it 'refuses to poll an absolute Location on a different host' do
      calls = stub_http(
        fake_response(303, '', { 'Location' => 'https://attacker.example.com/seller/asyncResult/xyz' }),
        fake_response(200, '{}')
      )

      expect { client.submit_app('1') }.to raise_error(
        FastlaneCore::Interface::FastlaneError, %r{unexpected location: https://attacker\.example\.com}
      )
      expect(calls.map(&:first)).to eq(['devapi.samsungapps.com'])
    end

    it 'refuses to poll a plain-HTTP Location' do
      stub_http(fake_response(303, '', { 'Location' => 'http://devapi.samsungapps.com/seller/asyncResult/xyz' }))

      expect { client.submit_app('1') }.to raise_error(FastlaneCore::Interface::FastlaneError, /unexpected location/)
    end

    it 'returns nil when the poll completes with 204' do
      stub_http(fake_response(303, '', { 'Location' => '/seller/asyncResult/abc' }), fake_response(204))
      expect(client.submit_app('1')).to be_nil
    end

    it 'keeps polling while the status is still pending' do
      stub_http(
        fake_response(303, '', { 'Location' => '/seller/asyncResult/abc' }),
        fake_response(202, ''),
        fake_response(200, '{"done":true}')
      )

      expect(client.submit_app('1')).to eq({ 'done' => true })
      expect(client).to have_received(:sleep).once
    end

    it 'raises a formatted error when the poll returns a failure code' do
      stub_http(
        fake_response(303, '', { 'Location' => '/seller/asyncResult/abc' }),
        fake_response(500, '{"errorMsg":"Processing failed"}')
      )

      expect { client.submit_app('1') }.to raise_error(
        FastlaneCore::Interface::FastlaneError,
        '[POST /seller/contentSubmit (async)] Request failed with status 500: Processing failed'
      )
    end

    it 'raises a timeout error when polling attempts are exhausted' do
      stub_http(fake_response(202, ''))

      expect do
        client.send(:poll_long_request, '/seller/asyncResult/abc', 'POST', '/seller/contentSubmit', attempts: 2, interval: 5)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Async request timed out after 10s/)
    end
  end

  describe '#mime_type_for' do
    {
      'app.apk' => 'application/vnd.android.package-archive',
      'app.aab' => 'application/x-authorware-bin',
      'icon.PNG' => 'image/png',
      'shot.jpg' => 'image/jpeg',
      'shot.jpeg' => 'image/jpeg',
      'anim.gif' => 'image/gif',
      'readme.txt' => 'application/octet-stream'
    }.each do |file_name, expected|
      it "maps #{file_name} to #{expected}" do
        expect(client.send(:mime_type_for, file_name)).to eq(expected)
      end
    end
  end

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
