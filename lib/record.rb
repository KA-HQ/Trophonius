# frozen_string_literal: true

# require 'time'
# require 'date_time'
# require 'date'
require 'active_support/inflector'
require 'json'
require 'config'
require 'translator'

module Trophonius
  # This class will hold a singular record
  #
  # A Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Record < Hash
    include Trophonius::Translator
    attr_accessor :record_id, :model_name, :layout_name, :modifiable_fields, :modified_fields

    ##
    # Initializes a new Record
    def initialize(fm_record = {}, model = '')
      @modifiable_fields = {}
      @modified_fields = {}
      @model_name = model
      @model = model_name.instance_of?(String) ? constantize_model(model_name) : model_name
      @layout_name = @model.layout_name
      @portals = []
      define_field_methods(fm_record) if fm_record.present?
      define_portal_methods(fm_record) if fm_record.present?
      super()
    end

    def to_param
      record_id.to_s
    end

    def []=(field, new_val)
      modifiable_fields[field] = new_val
      modified_fields[field] = new_val
      super
    end

    def method_missing(method, *args, &block)
      if ActiveSupport::Inflector.pluralize(method).to_s == method.to_s
        result = find_has_many_relation(method)
        return result if result
      elsif constantize_model(method).respond_to?('first')
        result = find_belongs_to_relation(method)
        return result if result
      end

      super
    rescue NameError => e
      if e.message.include?('constant')
        Error.throw_error('102', e.message.split(' ')[-1], layout_name)
      else
        raise e
      end
    end

    def respond_to_missing?(method, include_private = false)
      if ActiveSupport::Inflector.pluralize(method).to_s == method.to_s
        target_model = constantize_model(method)
        return true if target_model.belongs_to_relations[parameterize_name(model_name)]
      else
        target_model = constantize_model(method)
        relation_key = parameterize_name(ActiveSupport::Inflector.pluralize(model_name))
        return true if target_model.has_many_relations[relation_key]
      end
      super
    rescue NameError
      super
    end

    ##
    # Runs a FileMaker script from the context of the Model.
    #
    # @param [String] script: the FileMaker script to run
    #
    # @param [String] scriptparameter: the parameter required by the FileMaker script
    #
    # @return [String]: string representing the script result returned by FileMaker
    def run_script(script: '', scriptparameter: '')
      url = "layouts/#{layout_name}/records/#{record_id}?script=#{script}&script.param=#{scriptparameter}"
      result = DatabaseRequest.make_request(url, 'get', '{}')

      if result['messages'][0]['code'] != '0'
        Error.throw_error(result['messages'][0]['code'])
      elsif result['response']['scriptResult'] == '403'
        Error.throw_error(403)
      else
        ret_val = result['response']['scriptResult']
        ret_val || true
      end
    end

    ##
    # Saves the last changes made to the Record to FileMaker.
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def save
      url = "layouts/#{layout_name}/records/#{record_id}"

      @model.run_before_update
      body = "{\"fieldData\": #{modified_fields.to_json}}"
      response = DatabaseRequest.make_request(url, 'patch', body)
      @model.run_after_update
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end

    ##
    # Deletes the corresponding record from FileMaker
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def delete
      url = "layouts/#{layout_name}/records/#{record_id}"

      @model.run_before_destroy
      response = DatabaseRequest.make_request(url, 'delete', '{}')
      @model.run_after_destroy
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end

    ##
    # Changes and saves the corresponding record in FileMaker
    # Throws a FileMaker error if save failed
    #
    # @param [Hash] field_data: Fields to be changed and data to fill the fields with
    #
    # @return [True] if successful
    def update(field_data, portal_data: {})
      url = "layouts/#{layout_name}/records/#{record_id}"
      differences = calculate_differences_before_update(field_data, portal_data)
      return if  differences.all? { |diff| diff.length.zero? }

      field_data.each_key { |field| modifiable_fields[field] = field_data[field] }
      field_data.transform_keys! { |k| (@model.translations[k.to_s] || k).to_s }
      @model.run_before_update

      portal_data.each do |portal_name, values|
        values.map do |record|
          record.transform_keys! do |k|
            if k.to_s.downcase.include?('id') && k.to_s.downcase.include?('record')
              'recordId'
            else
              "#{portal_name}::#{k}"
            end
          end
        end
      end

      body = { fieldData: field_data }
      body.merge!({ portalData: portal_data }) if portal_data.present?

      response = DatabaseRequest.make_request(url, 'patch', body.to_json)
      code = response['messages'][0]['code']

      return throw_field_missing(field_data) if code == '102'
      return Error.throw_error(code) if code != '0'

      @model.run_after_update
      true
    end

    ##
    # Uploads a file to a container field of the record
    # Throws a FileMaker error if upload failed
    #
    # @param [String] container_name: Case sensitive name of the container field on the layout
    # @param [Integer] container_repetition: Number of the repetition of the container field to set
    # @param [Tempfile or File] file: File to upload
    #
    # @return [True] if successful
    def upload(container_name:, file:, container_repetition: 1)
      url = "layouts/#{layout_name}/records/#{record_id}/containers/#{container_name}/#{container_repetition}"

      response = DatabaseRequest.upload_file_request(url, file)
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end

    private

    def define_field_assignment(field_name, key)
      define_singleton_method("#{field_name}=") do |new_val|
        self[key] = new_val
        modifiable_fields[key] = new_val
        modified_fields[key] = new_val
      end
    end

    def define_field_methods(fm_record)
      @record_id = fm_record['recordId']

      fm_record['fieldData'].each_key do |key|
        method_name = methodize_field(key)
        define_singleton_method(method_name) { self[key] }
        merge!({ key => fm_record['fieldData'][key] })

        next if @model.non_modifiable_fields.include?(key)

        modifiable_fields.merge!({ key => fm_record['fieldData'][key] })
        define_field_assignment(method_name, key)
      end
    end

    def define_portal_methods(fm_record)
      fm_record['portalData'].each_key do |key|
        method_name = methodize_field(key)
        @portals.push(key)
        define_singleton_method(method_name) { self[key] }
        fm_record['portalData'][key].each do |portal_record|
          portal_record.each_key do |inner_key|
            inner_method = methodize_portal_field(inner_key)
            portal_record.send(:define_singleton_method, inner_method.to_s) { portal_record[inner_key] }
            portal_record.send(:define_singleton_method, 'record_id') { portal_record['recordId'] }
          end
        end
        merge!({ key => fm_record['portalData'][key] })
      end
    end

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

    def constantize_model(name)
      ActiveSupport::Inflector.constantize(
        ActiveSupport::Inflector.classify(
          ActiveSupport::Inflector.singularize(name.to_s)
        )
      )
    end

    def parameterize_name(name)
      ActiveSupport::Inflector.parameterize(name.to_s).to_sym
    end

    def resolve_field(model, field_key)
      model.create_translations if model.translations.keys.empty?
      if model.translations.key?(field_key)
        model.translations[field_key].to_s
      else
        field_key.to_s
      end
    end

    def build_relation_record_set(model, layout, data)
      ret_val = RecordSet.new(layout, model.non_modifiable_fields)
      data.each { |r| ret_val << model.build_result(r) }
      ret_val
    end

    def handle_relation_field_error(code, query_field, layout)
      return unless code == '102'

      results = DatabaseRequest.retrieve_first(layout)
      if results['messages'][0]['code'] == '0'
        r_results = results['response']['data']
        if r_results.empty?
          Error.throw_error('102')
        else
          ret_val = r_results[0]['fieldData']
          Error.throw_error('102', ([query_field] - ret_val.keys.map(&:downcase)).flatten.join(', '), layout)
        end
      else
        Error.throw_error('102')
      end
    end

    def execute_relation_query(target_model, query_field, query_value, limit:)
      layout = target_model.layout_name
      url = "/layouts/#{layout}/_find"
      body = { query: [{ query_field => query_value.to_s }], limit: limit }.to_json
      response = DatabaseRequest.make_request(url, 'post', body)
      code = response['messages'][0]['code']

      if code == '0'
        build_relation_record_set(target_model, layout, response['response']['data'])
      elsif code == '101' || code == '401'
        RecordSet.new(layout, target_model.non_modifiable_fields)
      else
        handle_relation_field_error(code, query_field, layout)
        Error.throw_error(code)
      end
    end

    def find_has_many_relation(method)
      target_model = constantize_model(method)
      current_model = constantize_model(model_name)
      relation = target_model.belongs_to_relations[parameterize_name(model_name)]
      return nil unless relation

      foreign_key_field = resolve_field(target_model, relation[:foreign_key])
      primary_key_field = resolve_field(current_model, relation[:primary_key])

      @response = execute_relation_query(
        target_model,
        foreign_key_field,
        self[primary_key_field],
        limit: 100_000
      )
    end

    def find_belongs_to_relation(method)
      current_model = constantize_model(model_name)
      target_model = constantize_model(method)
      relation = target_model.has_many_relations[parameterize_name(ActiveSupport::Inflector.pluralize(model_name))]
      return nil unless relation

      foreign_key_field = resolve_field(current_model, relation[:foreign_key])
      primary_key_field = resolve_field(target_model, relation[:primary_key])

      @response = execute_relation_query(
        target_model,
        primary_key_field,
        self[foreign_key_field],
        limit: 1
      )
      @response.first
    end

    def calculate_differences_before_update(field_data, portal_data)
      fields = self.reject { |k,v| @portals.include?(k) || !field_data.keys.include?(k) }
      portals = self.select { |k,v| @portals.include?(k) && portal_data.keys.include?(k) }

      updated_fields = field_data.present? ? field_data.to_set - fields.to_set  : []
      updated_portals = portal_data.present? ? portal_data.to_set - portals.to_set : []

      [updated_fields.to_h, updated_portals.to_h]
    end
  end
end
