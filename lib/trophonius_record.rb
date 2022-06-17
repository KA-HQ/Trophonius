# frozen_string_literal: true

require 'json'
require 'trophonius_config'

module Trophonius
  # This class will hold a singular record
  #
  # A Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Trophonius::Record < Hash
    attr_accessor :record_id, :model_name, :layout_name, :modifiable_fields, :modified_fields

    ##
    # Initializes a new Record
    def initialize(model = '')
      @modifiable_fields = {}
      @modified_fields = {}
      model_name = model
      @model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(model_name)))

      super
    end

    def []=(field, new_val)
      modifiable_fields[field] = new_val
      super
    end

    def method_missing(method, *args, &block)
      if ActiveSupport::Inflector.pluralize(method).to_s == method.to_s
        model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(method)))
        pk_model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(model_name)))

        if model.belongs_to_relations[ActiveSupport::Inflector.parameterize(model_name).to_sym]
          relation = model.belongs_to_relations[ActiveSupport::Inflector.parameterize(model_name).to_sym]
          layout = model.layout_name
          model.create_translations if model.translations.keys.empty?

          uri = URI::RFC2396_Parser.new
          url =
            URI(
              uri.escape(
                "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
                  Trophonius.config.database
                }/layouts/#{layout}/_find"
              )
            )

          foreign_key_field = if model.translations.key?(relation[:foreign_key])
                                model.translations[relation[:foreign_key]].to_s
                              else
                                relation[:foreign_key].to_s
                              end

          primary_key_field = if pk_model.translations.key?(relation[:primary_key])
                                pk_model.translations[relation[:primary_key]].to_s
                              else
                                relation[:primary_key].to_s
                              end

          body = { query: [{ foreign_key_field => self[primary_key_field].to_s }], limit: 100_000 }.to_json
          response = Request.make_request(url, "Bearer #{Request.get_token}", 'post', body)

          if response['messages'][0]['code'] == '0'
            r_results = response['response']['data']
            ret_val = RecordSet.new(layout, model.non_modifiable_fields)
            r_results.each do |r|
              hash = model.build_result(r)
              ret_val << hash
            end
            @response = ret_val
            @response
          elsif response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
            RecordSet.new(layout, model.non_modifiable_fields)

          else
            if response['messages'][0]['code'] == '102'
              results = Request.retrieve_first(layout)
              if results['messages'][0]['code'] == '0'
                r_results = results['response']['data']
                ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
                query_keys = [foreign_key_field]
                Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), layout)
              else
                Error.throw_error('102')
              end
            end
            Error.throw_error(response['messages'][0]['code'])
          end
        end
      elsif ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(method))).respond_to?('first')
        fk_model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(model_name)))
        pk_model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(method)))

        if pk_model.has_many_relations[ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.pluralize(model_name)).to_sym]
          relation = pk_model.has_many_relations[ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.pluralize(model_name)).to_sym]
          layout = pk_model.layout_name
          pk_model.create_translations if pk_model.translations.keys.empty?

          uri = URI::RFC2396_Parser.new
          url =
            URI(
              uri.escape(
                "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
                  Trophonius.config.database
                }/layouts/#{layout}/_find"
              )
            )

          foreign_key_field = if fk_model.translations.key?(relation[:foreign_key])
                                fk_model.translations[relation[:foreign_key]].to_s
                              else
                                relation[:foreign_key].to_s
                              end

          primary_key_field = if pk_model.translations.key?(relation[:primary_key])
                                pk_model.translations[relation[:primary_key]].to_s
                              else
                                relation[:primary_key].to_s
                              end

          body = { query: [{ primary_key_field => self[foreign_key_field].to_s }], limit: 1 }.to_json

          response = Request.make_request(url, "Bearer #{Request.get_token}", 'post', body)
          if response['messages'][0]['code'] == '0'
            r_results = response['response']['data']
            ret_val = RecordSet.new(layout, pk_model.non_modifiable_fields)
            r_results.each do |r|
              hash = pk_model.build_result(r)
              ret_val << hash
            end
            @response = ret_val
            @response.first
          elsif response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
            RecordSet.new(layout, pk_model.non_modifiable_fields)

          else
            if response['messages'][0]['code'] == '102'
              results = Request.retrieve_first(layout)
              if results['messages'][0]['code'] == '0'
                r_results = results['response']['data']
                ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
                query_keys = [primary_key_field]
                Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), layout)
              else
                Error.throw_error('102')
              end
            end
            Error.throw_error(response['messages'][0]['code'])
          end
        end
      else
        super
      end
    rescue NameError => e
      if e.message.include?('constant')
        Error.throw_error('102', e.message.split(' ')[-1], layout_name)
      else
        raise e
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
    def run_script(script: '', scriptparameter: '')
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}?script=#{script}&script.param=#{scriptparameter}"
          )
        )

      result = Request.make_request(url, "Bearer #{Request.get_token}", 'get', '{}')

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
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      body = "{\"fieldData\": #{modified_fields.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end

    ##
    # Deletes the corresponding record from FileMaker
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def delete
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'delete', '{}')
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
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      field_data.each_key { |field| modifiable_fields[field] = field_data[field] }
      new_portal_data = {}
      portal_data.each do |portal_name, portal_values|
        new_portal_data.merge!(
          portal_name =>
            portal_values.map do |record|
              record.each_with_object({}) do |(key, value), new_hash|
                if key.to_s.downcase.include?('id') && key.to_s.downcase.include?('record')
                  new_hash['recordId'] = value
                else
                  new_hash["#{portal_name}::#{key}"] = value
                end
              end
            end
        )
      end
      body =
        if new_portal_data == {}
          "{\"fieldData\": #{field_data.to_json} }"
        else
          "{\"fieldData\": #{field_data.to_json}, \"portalData\": #{new_portal_data.to_json}}"
        end

      puts "BODY SENT TO FILEMAKER WAS: #{body}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      if response['messages'][0]['code'] == '0'
        true
      else
        if response['messages'][0]['code'] == '102'
          results = Request.retrieve_first(layout_name)
          if results['messages'][0]['code'] == '0'
            r_results = results['response']['data']
            Error.throw_error('102') if r_results.empty?
            ret_val = r_results[0]['fieldData']
            Error.throw_error('102', (field_data.keys.map { |key| key.to_s.downcase } - ret_val.keys.map(&:downcase)).flatten.join(', '), layout_name)
          else
            Error.throw_error('102')
          end
        end
        Error.throw_error(response['messages'][0]['code'])
      end
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
      uri = URI::RFC2396_Parser.new
      url =
        URI(
          uri.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}/containers/#{container_name}/#{container_repetition}"
          )
        )

      response = Request.upload_file_request(url, "Bearer #{Request.get_token}", file)
      response['messages'][0]['code'] == '0' ? true : Error.throw_error(response['messages'][0]['code'])
    end
  end
end
