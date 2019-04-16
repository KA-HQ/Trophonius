require "json"
require "trophonius_config"
require "trophonius_record"
require "trophonius_recordset"
require "trophonius_error"

module Trophonius
  # this class will retrieve the records from the FileMaker database and build a RecordSet filled with records
  # the idea is that a Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Trophonius::Model
    attr_reader :all_fields
    def self.config(configuration)
      @configuration ||= Configuration.new
      @configuration.layout_name = configuration[:layout_name]
      @configuration.non_modifiable_fields = configuration[:non_modifiable_fields]
      @all_fields = {}
    end

    def self.layout_name
      @configuration.layout_name
    end

    def self.non_modifiable_fields
      @configuration.non_modifiable_fields
    end

    def self.create(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records")
      body = "{\"fieldData\": #{fieldData.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "post", body)
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{response["response"]["recordId"]}")
        ret_val = build_result(Request.make_request(url, "Bearer #{Request.get_token}", "get", "{}")["response"]["data"][0])
        ret_val.send(:define_singleton_method, "result_count") do
          1
        end
        return ret_val
      end
    end

    def self.where(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{self.layout_name}/_find")
      body = "{\"query\": [#{fieldData.to_json}]}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "post", body)
      if response["messages"][0]["code"] != "0"
        return RecordSet.new(self.layout_name, self.non_modifiable_fields) if response["messages"][0]["code"] == "101" || response["messages"][0]["code"] == "401"
        Error.throw_error(response["messages"][0]["code"])
      else
        r_results = response["response"]["data"]
        ret_val = RecordSet.new(self.layout_name, self.non_modifiable_fields)
        r_results.each do |r|
          hash = build_result(r)
          ret_val << hash
        end
        return ret_val
      end
    end

    def self.find(record_id)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{record_id}")
      response = Request.make_request(url, "Bearer #{Request.get_token}", "get", "{}")
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"], record_id)
      else
        ret_val = build_result(response["response"]["data"][0])
        ret_val.send(:define_singleton_method, "result_count") do
          1
        end
        return ret_val
      end
    end

    def self.delete(record_id)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{record_id}")
      response = Request.make_request(url, "Bearer #{Request.get_token}", "delete", "{}")
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        return true
      end
    end

    def self.edit(record_id, fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{record_id}")
      body = "{\"fieldData\": #{fieldData.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "patch", body)
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        true
      end
    end

    def self.build_result(result)
      hash = Trophonius::Record.new()
      hash.id = result["recordId"]
      hash.layout_name = layout_name
      result["fieldData"].keys.each do |key|
        unless key[/\s/] || key[/\W/]
          hash.send(:define_singleton_method, key.to_s) do
            hash[key]
          end
          unless non_modifiable_fields&.include?(key)
            @all_fields.merge!(key.to_s.downcase => key.to_s)
            hash.send(:define_singleton_method, "#{key.to_s}=") do |new_val|
              hash[key] = new_val
              hash.modifiable_fields[key] = new_val
            end
          end
        end
        hash.merge!({key => result["fieldData"][key]})
        unless non_modifiable_fields&.include?(key)
          hash.modifiable_fields.merge!({key => result["fieldData"][key]})
        end
      end
      result["portalData"].keys.each do |key|
        unless key[/\s/] || key[/\W/]
          hash.send(:define_singleton_method, key.to_s) do
            hash[key]
          end
        end
        result["portalData"][key].each_with_index do |inner_hash|
          inner_hash.keys.each do |inner_key|
            inner_method = inner_key.gsub(/\w+::/, "")
            unless inner_method[/\s/] || inner_method[/\W/]
              inner_hash.send(:define_singleton_method, inner_method.to_s) { inner_hash[inner_key] }
              inner_hash.send(:define_singleton_method, "id") { inner_hash["recordId"] }
            end
          end
        end
        hash.merge!({key => result["portalData"][key]})
      end
      return hash
    end

    def self.first
      results = Request.retrieve_first(layout_name)
      if results["messages"][0]["code"] != "0"
        Error.throw_error(results["messages"][0]["code"])
      else
        r_results = results["response"]["data"]
        ret_val = r_results.empty? ? Trophonius::Record.new({}) : build_result(r_results[0])
        ret_val.send(:define_singleton_method, "result_count") do
          r_results.empty? ? 0 : 1
        end
        return ret_val
      end
    end

    def self.run_script(script: "", scriptparameter: "")
      result = Request.run_script(script, scriptparameter, layout_name)
      if result["messages"][0]["code"] != "0"
        Error.throw_error(result["messages"][0]["code"])
      elsif result["response"]["scriptResult"] == "403"
        Error.throw_error(403)
      else
        ret_val = result["response"]["scriptResult"]
        return ret_val
      end
    end

    def self.all(sort: {})
      results = Request.retrieve_all(layout_name, sort)
      count = results["response"]["scriptResult"].to_i
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records?_limit=#{count == 0 ? 1000000 : count}")
      results = Request.make_request(url, "Bearer #{Request.get_token}", "get", "{}")
      if results["messages"][0]["code"] != "0"
        Error.throw_error(results["messages"][0]["code"])
      else
        r_results = results["response"]["data"]
        ret_val = RecordSet.new(self.layout_name, self.non_modifiable_fields)
        r_results.each do |r|
          hash = build_result(r)
          ret_val << hash
        end
        ret_val.result_count = count
        return ret_val
      end
    end
  end
end
