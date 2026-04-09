require 'net/http'
require 'uri'
require 'json'
require 'securerandom'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GalaxyStoreClient
      BASE_URL = 'https://devapi.samsungapps.com'

      def initialize(service_account_id, access_token)
        @service_account_id = service_account_id
        @access_token = access_token
      end

      def get_app_list
        uri = URI("#{BASE_URL}/seller/contentList")

        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def get_app_info(content_id)
        uri = URI("#{BASE_URL}/seller/contentInfo")
        uri.query = URI.encode_www_form(contentId: content_id)

        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def create_upload_session_id
        uri = URI("#{BASE_URL}/seller/createUploadSessionId")

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = handle_response(response)
        result['sessionId']
      end

      def upload_file(file_path)
        session_id = create_upload_session_id
        UI.message("Created upload session ID: #{session_id}")

        upload_uri = URI("https://seller.samsungapps.com/galaxyapi/fileUpload")
        boundary = "----RubyFormBoundary#{SecureRandom.hex(16)}"

        request = Net::HTTP::Post.new(upload_uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
        request.body = build_multipart_body(boundary, file_path, session_id)

        response = Net::HTTP.start(upload_uri.host, upload_uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def submit_app(content_id)
        uri = URI("#{BASE_URL}/seller/contentSubmit")

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate({ contentId: content_id })

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def create_update(content_id)
        uri = URI("#{BASE_URL}/seller/contentUpdate")

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate({ contentId: content_id })

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def get_staged_rollout_binaries(content_id, app_status)
        uri = URI("#{BASE_URL}/seller/v2/content/stagedRolloutBinary")
        uri.query = URI.encode_www_form(contentId: content_id, appStatus: app_status)

        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def get_staged_rollout_rate(content_id, app_status)
        uri = URI("#{BASE_URL}/seller/v2/content/stagedRolloutRate")
        uri.query = URI.encode_www_form(contentId: content_id, appStatus: app_status)

        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def update_content_metadata(payload)
        uri = URI("#{BASE_URL}/seller/contentUpdate")

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(payload)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      def add_binary(content_id, file_key)
        uri = URI("#{BASE_URL}/seller/v2/content/binary")

        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{@access_token}"
        request['service-account-id'] = @service_account_id
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate({
          contentId: content_id,
          gms: 'N',
          filekey: file_key
        })

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        handle_response(response)
      end

      private

      def build_multipart_body(boundary, file_path, session_id)
        file_name = File.basename(file_path)
        file_content = File.binread(file_path)
        mime_type = mime_type_for(file_path)

        body = String.new(encoding: 'BINARY')
        body << "--#{boundary}\r\n".b
        body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n".b
        body << "Content-Type: #{mime_type}\r\n\r\n".b
        body << file_content
        body << "\r\n--#{boundary}\r\n".b
        body << "Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".b
        body << session_id.b
        body << "\r\n--#{boundary}--\r\n".b
        body
      end

      def mime_type_for(file_path)
        case File.extname(file_path).downcase
        when '.apk' then 'application/vnd.android.package-archive'
        when '.aab' then 'application/x-authorware-bin'
        when '.png' then 'image/png'
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.gif' then 'image/gif'
        else 'application/octet-stream'
        end
      end

      def handle_response(response)
        case response.code.to_i
        when 200
          JSON.parse(response.body)
        when 204
          nil
        when 401
          UI.user_error!("Authentication failed. Check your access token and service account ID.")
        when 403
          UI.user_error!("Access denied. You do not have permission to access this resource.")
        when 404
          UI.user_error!("App not found. Check your content ID.")
        else
          UI.user_error!("Galaxy Store API request failed with status #{response.code}: #{response.body}")
        end
      end
    end
  end
end
