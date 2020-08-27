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
    def initialize
      @modifiable_fields = {}
      @modified_fields = {}
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

          url =
            URI(
              URI.escape(
                "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
                  Trophonius.config.database
                }/layouts/#{layout}/_find"
              )
            )

          if model.translations.key?(relation[:foreign_key])
            foreign_key_field = model.translations[relation[:foreign_key]].to_s
          else
            foreign_key_field = relation[:foreign_key].to_s
          end

          if pk_model.translations.key?(relation[:primary_key])
            primary_key_field = pk_model.translations[relation[:primary_key]].to_s
          else
            primary_key_field = relation[:primary_key].to_s
          end

          body = { query: [{ foreign_key_field => self[primary_key_field].to_s }], limit: 100_000 }.to_json
          response = Request.make_request(url, "Bearer #{Request.get_token}", 'post', body)

          if response['messages'][0]['code'] != '0'
            if response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
              resp = RecordSet.new(layout, model.non_modifiable_fields)
              return resp
            else
              if response['messages'][0]['code'] == '102'
                results = Request.retrieve_first(layout)
                if results['messages'][0]['code'] != '0'
                  Error.throw_error('102')
                else
                  r_results = results['response']['data']
                  ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
                  query_keys = [foreign_key_field]
                  Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), layout)
                end
              end
              Error.throw_error(response['messages'][0]['code'])
            end
          else
            r_results = response['response']['data']
            ret_val = RecordSet.new(layout, model.non_modifiable_fields)
            r_results.each do |r|
              hash = model.build_result(r)
              ret_val << hash
            end
            @response = ret_val
            return @response
          end
        end
      elsif ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(method))).respond_to?('first')
        fk_model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(model_name)))
        pk_model = ActiveSupport::Inflector.constantize(ActiveSupport::Inflector.classify(ActiveSupport::Inflector.singularize(method)))

        if pk_model.has_many_relations[ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.pluralize(model_name)).to_sym]
          relation = pk_model.has_many_relations[ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.pluralize(model_name)).to_sym]
          layout = pk_model.layout_name
          pk_model.create_translations if pk_model.translations.keys.empty?

          url =
            URI(
              URI.escape(
                "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
                  Trophonius.config.database
                }/layouts/#{layout}/_find"
              )
            )

          if fk_model.translations.key?(relation[:foreign_key])
            foreign_key_field = fk_model.translations[relation[:foreign_key]].to_s
          else
            foreign_key_field = relation[:foreign_key].to_s
          end

          if pk_model.translations.key?(relation[:primary_key])
            primary_key_field = pk_model.translations[relation[:primary_key]].to_s
          else
            primary_key_field = relation[:primary_key].to_s
          end

          body = { query: [{ primary_key_field => self[foreign_key_field].to_s }], limit: 1 }.to_json

          response = Request.make_request(url, "Bearer #{Request.get_token}", 'post', body)
          if response['messages'][0]['code'] != '0'
            if response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
              resp = RecordSet.new(layout, pk_model.non_modifiable_fields)
              return resp
            else
              if response['messages'][0]['code'] == '102'
                results = Request.retrieve_first(layout)
                if results['messages'][0]['code'] != '0'
                  Error.throw_error('102')
                else
                  r_results = results['response']['data']
                  ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
                  query_keys = [primary_key_field]
                  Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), layout)
                end
              end
              Error.throw_error(response['messages'][0]['code'])
            end
          else
            r_results = response['response']['data']
            ret_val = RecordSet.new(layout, pk_model.non_modifiable_fields)
            r_results.each do |r|
              hash = pk_model.build_result(r)
              ret_val << hash
            end
            @response = ret_val
            return @response.first
          end
        end
      else
        super
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
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}?script=#{script}&script.param=#{scriptparameter}"
          )
        )

      Request.make_request(url, "Bearer #{get_token}", 'get', '{}')
      if result['messages'][0]['code'] != '0'
        Error.throw_error(result['messages'][0]['code'])
      elsif result['response']['scriptResult'] == '403'
        Error.throw_error(403)
      else
        ret_val = result['response']['scriptResult']
        return ret_val
      end
    end

    ##
    # Saves the last changes made to the Record to FileMaker.
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def save
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      body = "{\"fieldData\": #{modified_fields.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      response['messages'][0]['code'] != '0' ? Error.throw_error(response['messages'][0]['code']) : true
    end

    ##
    # Deletes the corresponding record from FileMaker
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def delete
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'delete', '{}')
      response['messages'][0]['code'] != '0' ? Error.throw_error(response['messages'][0]['code']) : true
    end

    ##
    # Changes and saves the corresponding record in FileMaker
    # Throws a FileMaker error if save failed
    #
    # @param [Hash] fieldData: Fields to be changed and data to fill the fields with
    #
    # @return [True] if successful
    def update(fieldData)
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}"
          )
        )
      fieldData.keys.each { |field| modifiable_fields[field] = fieldData[field] }
      body = "{\"fieldData\": #{fieldData.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      if response['messages'][0]['code'] != '0'
        if response['messages'][0]['code'] == '102'
          results = Request.retrieve_first(layout_name)
          if results['messages'][0]['code'] != '0'
            Error.throw_error('102')
          else
            r_results = results['response']['data']
            ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
            Error.throw_error('102', (fieldData.keys.map(&:downcase) - ret_val.keys.map(&:downcase)).flatten.join(', '), layout_name)
          end
        end
        Error.throw_error(response['messages'][0]['code'])
      else
        true
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
    def upload(container_name:, container_repetition: 1, file:)
      url =
        URI(
          URI.escape(
            "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{
              Trophonius.config.database
            }/layouts/#{layout_name}/records/#{record_id}/containers/#{container_name}/#{container_repetition}"
          )
        )

      response = Request.upload_file_request(url, "Bearer #{Request.get_token}", file)
      response['messages'][0]['code'] != '0' ? Error.throw_error(response['messages'][0]['code']) : true
    end
  end
end
