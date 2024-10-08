require 'error'
require 'record'
require 'recordset'

module Trophonius
  class Single
    attr_reader :query

    def initialize(config:)
      @config = config
      @query = {}
      @translations = {}
      @all_fields = {}
    end

    def non_modifiable_fields
      []
    end

    def layout_name
      @config[:layout_name]
    end

    def where(fieldData)
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/layouts/#{
              @config[:layout_name]
            }/_find"
          )
        )
      @query.merge!(query: [fieldData])
      @query.merge!(limit: '10000000')
      token = setup_connection
      response = make_request(url, token, 'post', @query.to_json)

      r_results = response['response']['data']
      if response['messages'][0]['code'] != '0' && response['messages'][0]['code'] != '401'
        close_connection(token)
        Error.throw_error(response['messages'][0]['code'])
      elsif response['messages'][0]['code'] == '401'
        close_connection(token)
        return RecordSet.new(@config[:layout_name], @config[:non_modifiable_fields])
      else
        ret_val = RecordSet.new(@config[:layout_name], @config[:non_modifiable_fields])
        r_results.each do |r|
          hash = build_result(r)
          ret_val << hash
        end
      end
      @query = {}
      close_connection(token)

      ret_val
    end

    def first
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/layouts/#{
              @config[:layout_name]
            }/records?_limit=1"
          )
        )

      token = setup_connection
      response = make_request(url, token, 'get', @query.to_json)

      r_results = response['response']['data']
      if response['messages'][0]['code'] != '0' && response['messages'][0]['code'] != '401'
        close_connection(token)
        Error.throw_error(response['messages'][0]['code'])
      elsif response['messages'][0]['code'] == '401'
        close_connection(token)
        return RecordSet.new(@config[:layout_name], @config[:non_modifiable_fields])
      else
        ret_val = RecordSet.new(@config[:layout_name], @config[:non_modifiable_fields])
        r_results.each do |r|
          hash = build_result(r)
          ret_val << hash
        end
      end
      close_connection(token)

      ret_val
    end

    def run_script(script:, scriptparameter:)
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/layouts/#{
              @config[:layout_name]
            }/records?_limit=1&script=#{script}&script.param=#{scriptparameter}"
          )
        )

      token = setup_connection
      result = make_request(url, token.to_s, 'get', '{}')
      ret_val = ''

      if result['messages'][0]['code'] != '0'
        close_connection(token)
        Error.throw_error(result['messages'][0]['code'])
      elsif result['response']['scriptResult'] == '403'
        close_connection(token)
        Error.throw_error(403)
      else
        ret_val = result['response']['scriptResult']
      end

      close_connection(token)

      ret_val
    end

    private

    def build_result(result)
      record = Trophonius::Record.new(result, self)
      record.layout_name = @config[:layout_name]
      record
    end

    def make_request(url_param, token, method, body, params = '')
      ssl_verifyhost = @config[:local_network] ? 0 : 2
      ssl_verifypeer = !@config[:local_network]
      request =
        Typhoeus::Request.new(
          url_param,
          method: method.to_sym,
          body: body,
          params: params,
          ssl_verifyhost: ssl_verifyhost,
          ssl_verifypeer: ssl_verifypeer,
          headers: { 'Content-Type' => 'application/json', Authorization: "Bearer #{token}" }
        )
      temp = request.run
      begin
        JSON.parse(temp.response_body)
      rescue StandardError => e
        puts e
        close_connection(token)
        Error.throw_error('1631')
      end
    end

    def setup_connection
      ssl_verifyhost = @config[:local_network] ? 0 : 2
      ssl_verifypeer = !@config[:local_network]
      uri = URI::RFC2396_Parser.new
      url = URI(uri.escape("http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/sessions"))
      request =
        Typhoeus::Request.new(
          url,
          method: :post,
          body:
            if @config[:external_name].nil? || @config[:external_name].empty?
              {}
            else
              {
                fmDataSource: [{ database: @config[:external_name], username: @config[:external_username], password: @config[:external_password] }]
              }.to_json
            end,
          params: {},
          ssl_verifyhost: ssl_verifyhost,
          ssl_verifypeer: ssl_verifypeer,
          headers: {
            'Content-Type' => 'application/json', Authorization: "Basic #{Base64.strict_encode64("#{@config[:username]}:#{@config[:password]}")}"
          }
        )
      temp = request.run
      begin
        parsed = JSON.parse(temp.response_body)
      rescue StandardError => e
        puts e
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      parsed['response']['token']
    end

    def close_connection(token)
      uri = URI::RFC2396_Parser.new
      url =
        URI(uri.escape("http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/sessions/#{token}"))
      ssl_verifyhost = @config[:local_network] ? 0 : 2
      ssl_verifypeer = !@config[:local_network]

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
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      true
    end
  end
end
