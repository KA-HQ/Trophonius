require "json"
require "trophonius_config"
require "trophonius_record"
require "trophonius_recordset"
require "trophonius_error"

module Trophonius
  # This class will retrieve the records from the FileMaker database and build a RecordSet filled with Record objects. One Record object represents a record in FileMaker.
  class Trophonius::Model

    ##
    # Sets up the configuration for the model. 
    #
    # @param [Hash] configuration: the hash containing the config to setup the model correctly.
    #   configuration = {layout_name: "theFileMakerLayoutForThisModel", non_modifiable_fields: ["an", "array", "containing", "calculation_fields", "etc."]}
    def self.config(configuration)
      @configuration ||= Configuration.new
      @configuration.layout_name = configuration[:layout_name]
      @configuration.non_modifiable_fields = configuration[:non_modifiable_fields]
      @configuration.all_fields = {}
      @configuration.translations = {}
    end

    ##
    # Returns the FileMaker layout this Model corresponds to
    def self.layout_name
      @configuration.layout_name
    end
    
    ##
    # Returns the fields that FileMaker won't allow us to modify
    def self.non_modifiable_fields
      @configuration.non_modifiable_fields
    end

    ##
    # Returns the translations of the fields
    def self.translations
      @configuration.translations
    end
    
    def self.create_translations
      self.first
    end

    ##
    # Creates and saves a record in FileMaker
    # 
    # @param [Hash] fieldData: the fields to fill with the data
    #
    # @return [Record] the created record
    #   Model.create(fieldOne: "Data")
    def self.create(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records")
      new_field_data = {}
      if @configuration.translations.keys.empty?
        create_translations
      end
      fieldData.keys.each do |k|
        if @configuration.translations.keys.include?(k.to_s)
          new_field_data.merge!({"#{@configuration.translations[k.to_s]}" => fieldData[k]})
        else
          new_field_data.merge!({"#{k}" => fieldData[k]})
        end
      end
      body = "{\"fieldData\": #{new_field_data.to_json}}"
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
    
    ##
    # Finds and returns a RecordSet containing the records fitting the find request
    # 
    # @param [Hash] fieldData: the data to find
    #
    # @return [RecordSet] a RecordSet containing all the Record objects that correspond to FileMaker records fitting the find request
    #   Model.where(fieldOne: "Data")
    def self.where(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{self.layout_name}/_find")
      new_field_data = {}
      if @configuration.translations.keys.empty?
        create_translations
      end
      fieldData.keys.each do |k|
        if @configuration.translations.keys.include?(k.to_s)
          new_field_data.merge!({"#{@configuration.translations[k.to_s]}" => fieldData[k]})
        else
          new_field_data.merge!({"#{k}" => fieldData[k]})
        end
      end
      body = {query: [new_field_data], limit:"100000"}.to_json
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

    ##
    # Finds and returns a Record corresponding to the record_id
    # 
    # @param [Integer] record_id: the record id to retrieve from FileMaker
    # 
    # @return [Record] the record
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

    ##
    # Deletes a record from FileMaker
    # 
    # @param [Integer] record_id: the record id to retrieve from FileMaker
    #
    # @return [Boolean] True if the delete was successful 
    def self.delete(record_id)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{record_id}")
      response = Request.make_request(url, "Bearer #{Request.get_token}", "delete", "{}")
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        return true
      end
    end

    ##
    # Edits a record in FileMaker
    # 
    # @param [Integer] record_id: the record id to edit in FileMaker
    #
    # @param [Hash] fieldData: A hash containing the fields to edit and the new data to fill them with
    #
    # @return [Boolean] True if the delete was successful
    def self.edit(record_id, fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{record_id}")
      new_field_data = {}
      if @configuration.translations.keys.empty?
        create_translations
      end
      fieldData.keys.each do |k|
        if @configuration.translations.keys.include?(k.to_s)
          new_field_data.merge!({"#{@configuration.translations[k.to_s]}" => fieldData[k]})
        else
          new_field_data.merge!({"#{k}" => fieldData[k]})
        end
      end
      body = "{\"fieldData\": #{new_field_data.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "patch", body)
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        true
      end
    end

    ##
    # Builds the resulting Record
    # 
    # @param [JSON] result: the HTTP result from FileMaker
    #
    # @return [Record] A Record with singleton_methods for the fields where possible
    def self.build_result(result)
      hash = Trophonius::Record.new()
      hash.id = result["recordId"]
      hash.layout_name = layout_name
      result["fieldData"].keys.each do |key|
        # unless key[/\s/] || key[/\W/]
        @configuration.translations.merge!({ "#{ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_').downcase}" => "#{key}" })
        hash.send(:define_singleton_method, ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')) do
          hash[key]
        end
        unless non_modifiable_fields&.include?(key)
          @configuration.all_fields.merge!(ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_').downcase => ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_'))
          hash.send(:define_singleton_method, "#{ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')}=") do |new_val|
            hash[key] = new_val
            hash.modifiable_fields[key] = new_val
            hash.modified_fields[key] = new_val
          end
        end
        # end
        hash.merge!({key => result["fieldData"][key]})
        unless non_modifiable_fields&.include?(key)
          hash.modifiable_fields.merge!({key => result["fieldData"][key]})
        end
      end
      result["portalData"].keys.each do |key|
        unless key[/\s/] || key[/\W/]
          hash.send(:define_singleton_method, ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(key.to_s), separator: '_')) do
            hash[key]
          end
        end
        result["portalData"][key].each_with_index do |inner_hash|
          inner_hash.keys.each do |inner_key|
            inner_method = ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(inner_key.gsub(/\w+::/, "").to_s), separator: '_')
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

    ##
    # Retrieve the first record from FileMaker from the context of the Model.
    #
    # @return [Record]: a Record corresponding to the FileMaker record.
    def self.first
      results = Request.retrieve_first(layout_name)
      if results["messages"][0]["code"] != "0"
        Error.throw_error(results["messages"][0]["code"])
      else
        r_results = results["response"]["data"]
        ret_val = r_results.empty? ? Trophonius::Record.new() : build_result(r_results[0])
        ret_val.send(:define_singleton_method, "result_count") do
          r_results.empty? ? 0 : 1
        end
        return ret_val
      end
    end

    ##
    # Runs a FileMaker script from the context of the Model.
    #
    # @param [String] script: the FileMaker script to run 
    #
    # @param [String] scriptparameter: the parameter required by the FileMaker script
    #
    # @return [String]: string representing the script result returned by FileMaker
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

    ##
    # Retrieve the first 10000000 records from FileMaker from the context of the Model.
    #
    # @param [Hash] sort: a hash containing the fields to sort by and the direction to sort in (optional) 
    #
    # @return [RecordSet]: a RecordSet containing all the Record objects that correspond to the FileMaker records.
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
