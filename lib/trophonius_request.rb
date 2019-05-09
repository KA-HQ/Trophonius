require 'base64'
require 'trophonius_connection'

module Trophonius
  module Trophonius::Request
    ##
    # Crafts and runs a HTTP request of any type
    #
    # @param [URI] urlparam: the url to make the request to
    #
    # @param [String] auth: the authentication required for the request
    #
    # @param [String] method: the type of HTTP request to make (i.e. get)
    #
    # @param [JSONString] body: the body of the HTTP request
    #
    # @param [String] params: optional parameters added to the request
    #
    # @return [JSON] parsed json of the response
    def self.make_request(url_param, auth, method, body, params = '')
      ssl_verifyhost = Trophonius.config.local_network ? 0 : 2
      ssl_verifypeer = !Trophonius.config.local_network
      request = Typhoeus::Request.new(
        url_param,
        method: method.to_sym,
        body: body,
        params: params,
        ssl_verifyhost: ssl_verifyhost,
        ssl_verifypeer: ssl_verifypeer,
        headers: { 'Content-Type' => 'application/json', Authorization: auth.to_s }
      )
      temp = request.run
      begin
        JSON.parse(temp.response_body)
      rescue Exception
        Error.throw_error('1631')
      end
    end

    ##
    # Gets the current FileMaker token
    #
    # @return [String] a valid FileMaker token
    def self.get_token
      if Connection.valid_connection?
        Connection.token
      else
        Connection.connect
      end
    end

    ##
    # Retrieves the first record from FileMaker
    #
    # @return [JSON] The first record from FileMaker
    def self.retrieve_first(layout_name)
      url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=1")
      make_request(url, "Bearer #{get_token}", 'get', '{}')
    end

    ##
    # Runs a FileMaker script
    #
    # @return [JSON] The script result from FileMaker
    def self.run_script(script, scriptparameter, layout_name)
      url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=1&script=#{script}&script.param=#{scriptparameter}")
      make_request(url, "Bearer #{get_token}", 'get', '{}')
    end

    ##
    # Retrieves the 10000000 records from FileMaker
    #
    # @return [JSON] The first 10000000 records from FileMaker
    def self.retrieve_all(layout_name, sort)
      if !sort.empty?
        sort_order = sort.to_json.to_s
        url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=10000000_sort=#{sort_order}#{Trophonius.config.count_result_script == '' ? '' : "&script=#{Trophonius.config.count_result_script}"}")
      else
        url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=10000000#{Trophonius.config.count_result_script == '' ? '' : "&script=#{Trophonius.config.count_result_script}"}")
      end
      make_request(url, "Bearer #{get_token}", 'get', '{}')
    end
  end
end
