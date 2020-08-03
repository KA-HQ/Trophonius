require 'trophonius_date'
require 'trophonius_time'
require 'trophonius_error'
require 'trophonius_record'
require 'trophonius_recordset'

module Trophonius
  class Trophonius::Single
    attr_reader :query
    def initialize(config:)
      @config = config
      @query = {}
      @translations = {}
      @all_fields = {}
    end

    def where(fieldData)
      url =
        URI(
          URI.escape(
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
        Error.throw_error(response['messages'][0]['code'])
      elsif response['messages'][0]['code'] == '401'
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

      return ret_val
    end

    def run_script(script:, scriptparameter:)
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{@config[:layout_name]}/records?_limit=1&script=#{script}&script.param=#{scriptparameter}"
          )
        )

      token = setup_connection
      result = make_request(url, "Bearer #{token}", 'get', '{}')
      ret_val = ''

      if result['messages'][0]['code'] != '0'
        Error.throw_error(result['messages'][0]['code'])
      elsif result['response']['scriptResult'] == '403'
        Error.throw_error(403)
      else
        ret_val = result['response']['scriptResult']
      end

      close_connection(token)

      return ret_val
    end

    def run_script; end

    private

    def build_result(result)
      hash = Trophonius::Record.new
      hash.record_id = result['recordId']
      hash.layout_name = @config[:layout_name]
      hash.model_name = 'Single'

      result['fieldData'].keys.each do |key|
        # unless key[/\s/] || key[/\W/]
        @translations.merge!(
          { "#{ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_').downcase}" => "#{key}" }
        )
        hash.send(:define_singleton_method, ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')) do
          hash[key]
        end
        unless @config[:non_modifiable_fields]&.include?(key)
          @all_fields.merge!(
            ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_').downcase =>
              ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')
          )
          hash.send(
            :define_singleton_method,
            "#{ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')}="
          ) do |new_val|
            hash[key] = new_val
            hash.modifiable_fields[key] = new_val
            hash.modified_fields[key] = new_val
          end
        end
        # end
        hash.merge!({ key => result['fieldData'][key] })
        hash.modifiable_fields.merge!({ key => result['fieldData'][key] }) unless @config[:non_modifiable_fields]&.include?(key)
      end
      result['portalData'].keys.each do |key|
        unless key[/\s/] || key[/\W/]
          hash.send(:define_singleton_method, ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')) do
            hash[key]
          end
        end
        result['portalData'][key].each_with_index do |inner_hash|
          inner_hash.keys.each do |inner_key|
            inner_method =
              ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(inner_key.gsub(/\w+::/, '').to_s), separator: '_')
            unless inner_method[/\s/] || inner_method[/\W/]
              inner_hash.send(:define_singleton_method, inner_method.to_s) { inner_hash[inner_key] }
              inner_hash.send(:define_singleton_method, 'record_id') { inner_hash['recordId'] }
            end
          end
        end
        hash.merge!({ key => result['portalData'][key] })
      end
      return hash
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
      rescue Exception => e
        Error.throw_error('1631')
      end
    end

    def setup_connection
      ssl_verifyhost = @config[:local_network] ? 0 : 2
      ssl_verifypeer = !@config[:local_network]
      url = URI(URI.escape("http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/sessions"))
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
      rescue Exception => e
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      return parsed['response']['token']
    end

    def close_connection(token)
      url =
        URI(URI.escape("http#{@config[:ssl] == true ? 's' : ''}://#{@config[:host]}/fmi/data/v1/databases/#{@config[:database]}/sessions/#{token}"))
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
      rescue Exception => e
        Error.throw_error('1631')
      end
      Error.throw_error(parsed['messages'][0]['code']) if parsed['messages'][0]['code'] != '0'
      return true
    end
  end
end
