require "base64"
require "typhoeus"

module Trophonius
  module Trophonius::Connection
    def self.connect
      @token = setup_connection
      @last_connection = Time.current
      @token
    end

    def self.setup_connection
      @token = ""
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/sessions")

      request = Typhoeus::Request.new(
        url,
        method: :post,
        body: {},
        params: {},
        headers: { "Content-Type" => "application/json", Authorization: "Basic #{Base64.strict_encode64("#{Trophonius.config.username}:#{Trophonius.config.password}")}" }
      )
      temp = request.run
      if JSON.parse(temp.response_body)['messages'][0]['code'] != "0"
        Error.throw_error(response["messages"][0]["code"])
      end
      JSON.parse(temp.response_body)["response"]["token"]
    end

    def self.token
      @token
    end

    def self.last_connection
      @last_connection
    end

    def self.test_connection
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{Trophonius.config.layout_name}/records?_limit=1")
      begin
        request = Typhoeus::Request.new(
          url,
          method: :get,
          body: {},
          params: {},
          headers: { "Content-Type" => "application/json", Authorization: "Bearer #{@token}" }
        )
        temp = request.run
       JSON.parse(temp.response_body)['messages'][0]['code'] == "0"
      rescue
        return false
      end
    end

    def self.valid_connection?
      @last_connection.nil? ? false : (((Time.current - last_connection) / 1.minute).round <= 15 || test_connection)
    end
  end
end
