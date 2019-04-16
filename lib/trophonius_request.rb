require "base64"
require "trophonius_connection"

module Trophonius
  module Trophonius::Request
    def self.make_request(url_param, auth, method, body, params = "")
      request = Typhoeus::Request.new(
        url_param,
        method: method.to_sym,
        body: body,
        params: params,
        headers: { "Content-Type" => "application/json", Authorization: "#{auth}" }
      )
      temp = request.run
      JSON.parse(temp.response_body)
    end

    def self.get_token
      if Connection.valid_connection?
        Connection.token
      else
        Connection.connect
      end
    end

    def self.retrieve_first(layout_name)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=1")
      make_request(url, "Bearer #{get_token}", "get", "{}")
    end

    def self.run_script(script, scriptparameter, layout_name)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=1&script=#{script}&script.param=#{scriptparameter}")
      make_request(url, "Bearer #{get_token}", "get", "{}")
    end

    def self.retrieve_all(layout_name, sort)
      if !sort.empty?
        sort_order = "#{sort.to_json}"
        url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_sort=#{sort_order}#{Trophonius.config.count_result_script == "" ? "" : "&script=#{Trophonius.config.count_result_script}"}")
      else
        url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records#{Trophonius.config.count_result_script == "" ? "" : "?script=#{Trophonius.config.count_result_script}"}")
      end
      make_request(url, "Bearer #{get_token}", "get", "{}")
    end
  end
end
