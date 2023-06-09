# frozen_string_literal: true

require 'base64'
require 'connectors/connection_manager'
require 'typhoeus'
require 'uri'
require 'securerandom'
require 'net/http'

module Trophonius
  module DatabaseRequest
    ##
    # Crafts and runs a HTTP request of any type
    #
    # @param [URI] url_path: the url to make the request to
    #
    # @param [String] method: the type of HTTP request to make (i.e. get)
    #
    # @param [JSONString] body: the body of the HTTP request
    #
    # @param [String] params: optional parameters added to the request
    #
    # @param [String] bypass_queue_with: optional way to bypass the ConnectionManager
    #
    # @return [JSON] parsed json of the response
    def self.make_request(url_path, method, body, params = '', bypass_queue_with: '')
      ssl_verifyhost = Trophonius.config.local_network ? 0 : 2
      ssl_verifypeer = !Trophonius.config.local_network
      base_url = "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}"
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape("#{base_url}/#{url_path}")
        )

      id = SecureRandom.uuid
      auth = bypass_queue_with.empty? ? auth_header_bearer(id) : bypass_queue_with

      request =
        Typhoeus::Request.new(
          url,
          method: method.to_sym,
          body: body,
          params: params,
          ssl_verifyhost: ssl_verifyhost,
          ssl_verifypeer: ssl_verifypeer,
          headers: { 'Content-Type' => 'application/json', Authorization: auth }
        )
      temp = request.run
      Trophonius.connection_manager.dequeue(id) if bypass_queue_with.empty?

      begin
        JSON.parse(temp.response_body)
      rescue StandardError => e
        puts e
        puts e.backtrace
        Error.throw_error('1631')
      end
    end

    ##
    # Crafts and runs a HTTP request for uploading a file to a container
    #
    # @param [URI] urlparam: the url to make the request to
    #
    # @param [String] auth: the authentication required for the request
    #
    # @param [Tempfile or File] file: file to upload
    #
    # @return [JSON] parsed json of the response
    def self.upload_file_request(url_param, file)
      base_url = "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}"
      url = URI("#{base_url}/#{url_param}")

      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request['Authorization'] = auth_header_bearer(id)
      request['Content-Type'] = 'multipart/form-data;'
      form_data = [['upload', file]]
      request.set_form form_data, 'multipart/form-data'
      response = https.request(request)
      Trophonius.connection_manager.dequeue(id)
      begin
        JSON.parse(response.read_body)
      rescue StandardError
        Error.throw_error('1631')
      end
    end

    ##
    # Gets a valid auth header containing the access token
    #
    # @return [String] a valid auth header containing the access token
    def self.auth_header_bearer(id)
      Trophonius.connection_manager.enqueue(id)
    end

    ##
    # Retrieves the first record from FileMaker
    #
    # @return [JSON] The first record from FileMaker
    def self.retrieve_first(layout_name)
      make_request("layouts/#{layout_name}/records?_limit=1", 'get', '{}')
    end

    ##
    # Retrieves the fieldnames of a layout
    #
    # @return [JSON] The fieldnames of a layout
    def self.get_layout_field_names(layout_name)
      make_request("layouts/#{layout_name}", 'get', '{}')['response']['fieldMetaData'].map { |field| field['name'] }
    rescue StandardError => e
      puts e
      puts e.backtrace
      Error.throw_error('1631')
    end

    ##
    # Runs a FileMaker script
    #
    # @return [JSON] The script result from FileMaker
    def self.run_script(script, scriptparameter, layout_name)
      make_request("/layouts/#{layout_name}/records?_limit=1&script=#{script}&script.param=#{scriptparameter}", 'get', '{}')
    end

    ##
    # Retrieves the 10000000 records from FileMaker
    #
    # @return [JSON] The first 10000000 records from FileMaker
    def self.retrieve_all(layout_name, sort)
      path = "layouts/#{layout_name}/records?_limit=10000000#{
        Trophonius.config.count_result_script == '' ? '' : "&script=#{Trophonius.config.count_result_script}"
      }"
      path += "&_sort=#{sort_order}" if sort.present?
      path += "&script=#{Trophonius.config.count_result_script}" if Trophonius.config.count_result_script.present?
      make_request(path, 'get', '{}')
    end
  end
end
