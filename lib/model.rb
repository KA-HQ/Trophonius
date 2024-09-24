require 'json'
require 'config'
require 'record'
require 'recordset'
require 'translator'
require 'query'
require 'error'
# require 'time'
# require 'date_time'
# require 'date'

require 'active_support/inflector'

module Trophonius
  # This class will retrieve the records from the FileMaker database and build a RecordSet filled with Record objects.
  # One Record object represents a record in FileMaker.
  class Model
    attr_reader :configuration
    attr_accessor :current_query

    def initialize(config:)
      @configuration = config
      @offset = ''
      @limit = ''
    end

    ##
    # Sets up the configuration for the model.
    #
    # @param [Hash] configuration: the hash containing the config to setup the model correctly.
    #   configuration = {layout_name: "theFileMakerLayoutForThisModel",
    #   non_modifiable_fields: ["an", "array", "containing", "calculation_fields", "etc."]}
    def self.config(configuration)
      @configuration ||= Configuration.new
      @configuration.layout_name = configuration[:layout_name]
      @configuration.non_modifiable_fields = configuration[:non_modifiable_fields] || []
      @configuration.translations = {}
      @configuration.has_many_relations = {}
      @configuration.belongs_to_relations = {}
      @configuration.callbacks = { before_create: [], before_update: [], before_destroy: [], after_create: [], after_update: [], after_destroy: [] }
      @offset = ''
      @limit = ''
    end

    def self.scope(name, procedure)
      define_singleton_method(name) do |*args|
        procedure.arity.zero? ? procedure.call : procedure.call(args)
      end
    end

    def self.after_create(procedure, args)
      @configuration.callbacks[:after_create].push({ name: procedure, args: args })
    end

    def self.run_after_create
      @configuration.callbacks[:after_create].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    def self.after_update(procedure, args)
      @configuration.callbacks[:after_update].push({ name: procedure, args: args })
    end

    def self.run_after_update
      @configuration.callbacks[:after_update].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    def self.after_destroy(procedure, args)
      @configuration.callbacks[:after_destroy].push({ name: procedure, args: args })
    end

    def self.run_after_destroy
      @configuration.callbacks[:after_destroy].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    def self.before_create(procedure, args)
      @configuration.callbacks[:before_create].push({ name: procedure, args: args })
    end

    def self.run_before_create
      @configuration.callbacks[:before_create].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    def self.before_update(procedure, args)
      @configuration.callbacks[:before_update].push({ name: procedure, args: args })
    end

    def self.run_before_update
      @configuration.callbacks[:before_update].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    def self.before_destroy(procedure, args)
      @configuration.callbacks[:before_destroy].push({ name: procedure, args: args })
    end

    def self.run_before_destroy
      @configuration.callbacks[:before_destroy].each do |callback|
        procedure = callback[:name]
        args = callback[:args]
        procedure.is_a?(Proc) ? procedure.call(args) : send(procedure, args)
      end
    end

    ##
    # Add a belongs to relationship.
    #
    # @param [Symbol] model_name: the name of the model to build a relation with
    # @param [String] primary_key: the name of the field containing the primary to build the relation over
    # @param [String] foreign_key: the name of the field containing the primary to build the relation over
    def self.belongs_to(model_name, primary_key:, foreign_key:)
      @configuration.belongs_to_relations.merge!({ model_name => { primary_key: primary_key, foreign_key: foreign_key } })
    end

    ##
    # Add a has many relationship.
    #
    # @param [Symbol] model_name: the name of the model to build a relation with
    # @param [String] primary_key: the name of the field containing the primary to build the relation over
    # @param [String] foreign_key: the name of the field containing the primary to build the relation over
    def self.has_many(model_name, primary_key:, foreign_key:)
      @configuration.has_many_relations.merge!({ model_name => { primary_key: primary_key, foreign_key: foreign_key } })
    end

    ##
    # Limits the found record set.
    #
    # @param [Integer] page: number of current page
    # @param [Integer] limit: number of records retreived
    #
    # @return [Trophonius::Model] Self
    def self.paginate(page, limit)
      @offset = (((page * limit) - limit) + 1).to_s
      @limit = limit.to_s
      self
    end

    ##
    # Returns the FileMaker layout this Model corresponds to
    #
    # @return [String] layout name of the model
    def self.layout_name
      @configuration.layout_name
    end

    ##
    # Returns the Hash containing the related parent models
    #
    # @return [Hash] child models
    def self.has_many_relations
      @configuration.has_many_relations
    end

    ##
    # Returns the Hash containing the related parent models
    #
    # @return [Hash] parent models
    def self.belongs_to_relations
      @configuration.belongs_to_relations
    end

    ##
    # Returns the fields that FileMaker won't allow us to modify
    #
    # @return [[Array]] fields that FileMaker won't allow us to modify
    def self.non_modifiable_fields
      @configuration.non_modifiable_fields
    end

    ##
    # Returns the translations of the fields
    #
    # @return [Hash] translations of the fields Rails -> FileMaker
    def self.translations
      @configuration.translations
    end

    ##
    # creates Rails -> FileMaker field translations by requesting the first record
    #
    # @return [Hash] translations of the fields Rails -> FileMaker
    def self.create_translations
      extend Trophonius::Translator
      field_names = if Trophonius.config.fm_18
                      Trophonius::DatabaseRequest.get_layout_field_names(layout_name)
                    else
                      DatabaseRequest.retrieve_first(layout_name).dig(
                        'response', 'data', 0, 'fieldData'
                      ).keys
                    end
      field_names.each do |field|
        new_name = methodize_field(field.to_s).to_s
        @configuration.translations.merge!(
          { new_name => field.to_s }
        )
      end
      @configuration.translations
    end

    def self.method_missing(method, *args)
      new_instance = Trophonius::Model.new(config: @configuration)
      new_instance.current_query = Trophonius::Query.new(trophonius_model: self, limit: @limit, offset: @offset)
      args << new_instance
      new_instance.current_query.send(method, args) if new_instance.current_query.respond_to?(method)
    end

    def method_missing(method, *args, &block)
      if @current_query.respond_to?(method)
        args << self
        @current_query.send(method, args)
      elsif @current_query.response.respond_to?(method)
        ret_val = @current_query.run_query(method, *args, &block)
        @limit = ''
        @offset = ''
        ret_val
      end
    end

    ##
    # Finds all records in FileMaker corresponding to the requested query
    # @param [Hash] fieldData: the data to find
    #
    # @return [Trophonius::Model] new instance of the model
    def self.where(field_data)
      create_translations if @configuration.translations.keys.empty?

      new_instance = Trophonius::Model.new(config: @configuration)
      new_instance.current_query = Trophonius::Query.new(trophonius_model: self, limit: @limit, offset: @offset)
      new_instance.current_query.build_query[0].merge!(field_data)
      new_instance
    end

    ##
    # Finds all records in FileMaker corresponding to the requested query
    # This method is created to enable where chaining
    #
    # @param [Hash] fieldData: the data to find
    #
    # @return [Trophonius::Model] new instance of the model
    def where(field_data)
      @current_query.build_query[0].merge!(field_data)
      self
    end

    ##
    # Creates and saves a record in FileMaker
    #
    # @param [Hash] fieldData: the fields to fill with the data
    #
    # @return [Record] the created record
    #   Model.create(fieldOne: "Data")
    def self.create(field_data, portal_data: {})
      create_translations if @configuration.translations.keys.empty?
      run_before_create

      field_data.transform_keys! { |k| (@configuration.translations[k.to_s] || k).to_s }

      portal_data.each do |portal_name, values|
        values.map { |record| record.transform_keys! { |k| "#{portal_name}::#{k}" } }
      end

      body = { fieldData: field_data }
      body.merge!({ portalData: portal_data }) if portal_data.present?

      response = DatabaseRequest.make_request("/layouts/#{layout_name}/records", 'post', body.to_json)

      return throw_field_missing(field_data) if response['messages'][0]['code'] == '102'

      return Error.throw_error(response['messages'][0]['code']) if response['messages'][0]['code'] != '0'

      new_record = DatabaseRequest.make_request("/layouts/#{layout_name}/records/#{response['response']['recordId']}", 'get', '{}')
      record = build_result(new_record['response']['data'][0])
      record.send(:define_singleton_method, 'result_count') { 1 }
      run_after_create

      record
    end

    ##
    # Finds and returns the first Record containing fitting the find request
    #
    # @param [Hash] fieldData: the data to find
    #
    # @return [Record] a Record object that correspond to FileMaker record fitting the find request
    #   Model.find_by(fieldOne: "Data")
    def self.find_by(field_data)
      url = "layouts/#{layout_name}/_find?_limit=1"
      create_translations if @configuration.translations.keys.empty?

      field_data.transform_keys! { |k| (@configuration.translations[k.to_s] || k).to_s }

      body = { query: [field_data], limit: '1' }.to_json
      response = DatabaseRequest.make_request(url, 'post', body)
      code = response['messages'][0]['code']

      return nil if %w[101 401].include?(code)

      Error.throw_error(code) if code != '0'

      r_results = response['response']['data']
      build_result(r_results.first) if r_results.first.present?
    end

    ##
    # Finds and returns a Record corresponding to the record_id
    #
    # @param [Integer] record_id: the record id to retrieve from FileMaker
    #
    # @return [Record] the record
    def self.find(record_id)
      create_translations if @configuration.translations.keys.empty?

      url = "layouts/#{layout_name}/records/#{record_id}"
      response = DatabaseRequest.make_request(url, 'get', '{}')
      if response['messages'][0]['code'] == '0'
        ret_val = build_result(response['response']['data'][0])
        ret_val.send(:define_singleton_method, 'result_count') { 1 }
        ret_val
      else
        Error.throw_error(response['messages'][0]['code'], record_id)
      end
    end

    ##
    # Deletes a record from FileMaker
    #
    # @param [Integer] record_id: the record id to retrieve from FileMaker
    #
    # @return [Boolean] True if the delete was successful
    def self.delete(record_id)
      create_translations if @configuration.translations.keys.empty?

      url = "layouts/#{layout_name}/records/#{record_id}"
      response = DatabaseRequest.make_request(url, 'delete', '{}')

      if response['messages'][0]['code'] == '0'
        true
      else
        Error.throw_error(response['messages'][0]['code'])
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
    def self.edit(record_id, field_data)
      url = "layouts/#{layout_name}/records/#{record_id}"
      new_field_data = {}
      create_translations if @configuration.translations.keys.empty?

      field_data.each_key do |k|
        field_name = (@configuration.translations[k.to_s] || k).to_s
        new_field_data.merge!({ field_name => field_data[k] })
      end

      body = "{\"fieldData\": #{new_field_data.to_json}}"
      response = DatabaseRequest.make_request(url, 'patch', body)
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end

    ##
    # Builds the resulting Record
    #
    # @param [JSON] result: the HTTP result from FileMaker
    #
    # @return [Record] A Record with singleton_methods for the fields where possible
    def self.build_result(result)
      record = Trophonius::Record.new(result, name)
      record.layout_name = layout_name
      record
    end

    ##
    # Retrieve the first record from FileMaker from the context of the Model.
    #
    # @return [Record]: a Record corresponding to the FileMaker record.
    def self.first
      create_translations if @configuration.translations.keys.empty?
      results = DatabaseRequest.retrieve_first(layout_name)
      if results['messages'][0]['code'] == '0'
        r_results = results['response']['data']
        ret_val = r_results.empty? ? Trophonius::Record.new({}, name) : build_result(r_results[0])
        ret_val.send(:define_singleton_method, 'result_count') { r_results.empty? ? 0 : 1 }
        ret_val
      else
        Error.throw_error(results['messages'][0]['code'])
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
    def self.run_script(script: '', scriptparameter: '')
      create_translations if @configuration.translations.keys.empty?
      result = DatabaseRequest.run_script(script, scriptparameter, layout_name)
      if result['messages'][0]['code'] != '0'
        Error.throw_error(result['messages'][0]['code'])
      elsif result['response']['scriptResult'] == '403'
        Error.throw_error(403)
      else
        result['response']['scriptResult']
      end
    end

    ##
    # Retrieve the first 10000000 records from FileMaker from the context of the Model.
    #
    # @param [Hash] sort: a hash containing the fields to sort by and the direction to sort in (optional)
    #
    # @return [RecordSet]: a RecordSet containing all the Record objects that correspond to the FileMaker records.
    def self.all(sort: {})
      create_translations if @configuration.translations.keys.empty?
      path = "/layouts/#{layout_name}/records?"
      path += @limit.present? ? "_limit=#{@limit}" : '_limit=10000000'
      path += "&_offset=#{@offset}" if @offset.present?
      sort = sort.map { |k, v| { fieldName: k, sortOrder: v } }
      path += "&_sort=#{sort.to_json}" unless sort.blank?

      @limit = ''
      @offset = ''
      results = DatabaseRequest.make_request(path, 'get', '{}')
      if results['messages'][0]['code'] == '0'
        r_results = results['response']['data']
        ret_val = RecordSet.new(layout_name, non_modifiable_fields)
        r_results.each do |r|
          hash = build_result(r)
          ret_val << hash
        end
        ret_val.result_count = count
        ret_val
      else
        Error.throw_error(results['messages'][0]['code'])
      end
    end

    private

    def throw_field_missing(field_data)
      results = DatabaseRequest.retrieve_first(layout_name)
      if results['messages'][0]['code'] == '0' && !results['response']['data'].empty?
        r_results = results['response']['data']
        ret_val = r_results[0]['fieldData']
        Error.throw_error('102', (field_data.keys.map(&:downcase) - ret_val.keys.map(&:downcase)).flatten.join(', '), layout_name)
      else
        Error.throw_error('102')
      end
    end
  end
end
