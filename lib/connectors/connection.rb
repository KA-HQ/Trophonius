require 'time'
require 'base64'
require 'securerandom'
require 'connectors/redis_manager'

module Trophonius
  class Connection
    attr_reader :id

    def initialize
      @id = SecureRandom.uuid
      @token = ''
      connect
    end

    ##
    # Returns the last received token
    # @return [String] the last valid *token* used to connect with the FileMaker data api
    def token
      if valid_connection?
        Trophonius.config.redis_connection ? Trophonius::RedisManager.get_key(key: 'token') : @token
      else
        connect
      end
    end

    private

    ##
    # Creates a new connection to FileMaker
    #
    # @return [String] the *token* used to connect with the FileMaker data api

    def connect
      if Trophonius.config.redis_connection
        Trophonius::RedisManager.set_key(key: 'token', value: setup_connection)
        Trophonius::RedisManager.set_key(key: 'last_connection', value: Time.now)
        Trophonius::RedisManager.get_key(key: 'token')
      else
        @token = setup_connection
        @last_connection = Time.now
        @token
      end
    end

    def reset_token
      if Trophonius.config.redis_connection
        Trophonius::RedisManager.set_key(key: 'token', value: '')
        Trophonius::RedisManager.set_key(key: 'last_connection', value: nil)
      else
        @token = ''
        @last_connection = nil
      end
    end

    def fm_external_data_source
      if Trophonius.config.external_name.empty?
        {}
      else
        {
          fmDataSource: [
            {
              database: Trophonius.config.external_name,
              username: Trophonius.config.external_username,
              password: Trophonius.config.external_password
            }
          ]
        }.to_json
      end
    end

    ##
    # Creates and runs a HTTP request to create a new data api connection
    # This method throws an error when the request returns with a HTTP error or a FileMaker error
    # @return [String] the *token* used to connect with the FileMaker data api if successful

    def setup_connection
      reset_token

      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/sessions"
          )
        )
      ssl_verifyhost = Trophonius.config.local_network ? 0 : 2
      ssl_verifypeer = !Trophonius.config.local_network
      request =
        Typhoeus::Request.new(
          url,
          method: :post,
          body: fm_external_data_source,
          params: {},
          ssl_verifyhost: ssl_verifyhost,
          ssl_verifypeer: ssl_verifypeer,
          headers: {
            'Content-Type' => 'application/json',
            Authorization: "Basic #{Base64.strict_encode64("#{Trophonius.config.username}:#{Trophonius.config.password}")}"
          }
        )
      temp = request.run
      body = temp.response_body

      begin
        parsed = JSON.parse(body)
      rescue StandardError => e
        puts e
        puts e.backtrace
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      parsed['response']['token']
    end

    ##
    # Disconnects from the FileMaker server
    #
    def disconnect
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/sessions/#{Trophonius.config.redis_connection ? Trophonius::RedisManager.get_key(key: 'token') : @token}"
          )
        )
      ssl_verifyhost = Trophonius.config.local_network ? 0 : 2
      ssl_verifypeer = !Trophonius.config.local_network

      request =
        Typhoeus::Request.new(
          url,
          method: :delete,
          params: {},
          ssl_verifyhost: ssl_verifyhost,
          ssl_verifypeer: ssl_verifypeer,
          headers: { 'Content-Type' => 'application/json' }
        )
      temp = request.run

      begin
        parsed = JSON.parse(temp.response_body)
      rescue StandardError => e
        puts e
        puts e.backtrace
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      Trophonius::RedisManager.disconnect! if Trophonius.config.redis_connection
      @token = nil
      @last_connection = nil
      true
    end

    ##
    # Returns the receive time of the last received token
    # @return [Time] Returns the receive time of the last received token
    def last_connection
      last = Trophonius.config.redis_connection ? Trophonius::RedisManager.get_key(key: 'last_connection') : nil
      last = last.nil? ? nil : Time.parse(last)
      Trophonius.config.redis_connection ? last : @last_connection
    end

    ##
    # Tests whether the FileMaker token is still valid
    # @return [Boolean] True if the token is valid False if invalid
    def test_connection
      return last_connection.nil? || last_connection < Time.now - (15 * 60) if Trophonius.config.layout_name == ''

      path = "/layouts/#{Trophonius.config.layout_name}/records?_limit=1"
      response =
        Trophonius::DatabaseRequest.make_request(path, :get, {}, bypass_queue_with: "Bearer #{@token}")
      response['messages'][0]['code'] == '0'
    rescue StandardError => e
      puts e
      puts e.backtrace
      false
    end

    ##
    # Returns whether the current connection is still valid
    # @return [Boolean] True if the connection is valid False if invalid
    def valid_connection?
      if Trophonius.config.layout_name != '' && test_connection == false
        false
      else
        last_connection.nil? ? false : test_connection
      end
    end
  end
end
