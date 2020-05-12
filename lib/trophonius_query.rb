require 'json'
require 'trophonius_config'
require 'trophonius_record'
require 'trophonius_recordset'
require 'trophonius_error'

module Trophonius
  class Trophonius::Query
    attr_reader :response

    ##
    # Creates a new instance of the Trophonius::Query class
    #
    # @param [Trophonius::Model] trophonius_model: base model for the new query
    # @param [String] limit: Used for every query to set the limit
    # @param [String] offset: Used for every query to set the offset
    # @return [Trophonius::Query] new instance of Trophonius::Query
    def initialize(trophonius_model:, limit:, offset:)
      @response = RecordSet.new(trophonius_model.layout_name, trophonius_model.non_modifiable_fields)
      @trophonius_model = trophonius_model
      @limit = limit
      @offset = offset
    end

    ##
    # Returns the current query, creates an empty query if no current query exists
    #
    # @return [Array[Hash]] array representing the FileMaker find request
    def build_query
      @current_query ||= [{}]
    end

    ##
    # Returns the current sort order, creates an empty sort order if no current sort order exists
    #
    # @return [Array[Hash]] array representing the FileMaker sort request
    def build_sort
      @current_sort ||= [{}]
    end

    def inspect
      @current_query
    end

    ##
    # Adds a find request to the original query, resulting in an "Or" find-request for FileMaker
    #
    # @param [args] arguments containing a Hash containing the FileMaker find request, and the base model object for the query
    # @return [Trophonius::Model] updated base model
    def or(args)
      args[1].current_query.build_query << args[0]
      args[1]
    end

    ##
    # Adds an omit request to the original query, resulting in an "omit" find for FileMaker
    #
    # @param [args] arguments containing a Hash containing the FileMaker omit request, and the base model object for the query
    # @return [Trophonius::Model] updated base model
    def not(args)
      args[1].current_query.build_query << args[0].merge!(omit: true)
      args[1]
    end

    ##
    # Sets or updates the limit and offset for a query
    #
    # @param [args] arguments containing the limit and offset
    # @return [Trophonius::Model] updated base model
    def paginate(args)
      @offset = args[0]
      @limit = args[1]
      args[2]
    end

    ##
    # Adds an sort request to the original query, resulting in an "sorted" query
    #
    # @param [args] arguments containing a Hash containing the FileMaker sort request, and the base model object for the query
    # @return [Trophonius::Model] updated base model
    def sort(args)
      args[1].current_query.build_sort << args[0]
      args[1]
    end

    ##
    # Performs the query in FileMaker
    #
    # @param [method] original called method, will be called on the response
    # @param [*args] original arguments, will be passed to the method call
    # @param [&block] original block, will be passed to the method call
    #
    # @return Response of the called method
    def run_query(method, *args, &block)
      url =
        URI(
          "http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{
            @trophonius_model.layout_name
          }/_find"
        )
      new_field_data = @current_query.map { |_q| {} }
      @trophonius_model.create_translations if @trophonius_model.translations.keys.empty?
      @current_query.each_with_index do |query, index|
        query.keys.each do |k|
          if @trophonius_model.translations.key?(k.to_s)
            new_field_data[index].merge!(@trophonius_model.translations[k.to_s].to_s => query[k].to_s)
          else
            new_field_data[index].merge!(k.to_s => query[k].to_s)
          end
        end
      end
      if @offset.empty? || @limit.empty?
        body = { query: new_field_data, limit: '100000' }.to_json
      else
        body = { query: new_field_data, limit: @limit.to_s, offset: @offset.to_s }.to_json
      end
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'post', body)
      if response['messages'][0]['code'] != '0'
        if response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
          RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields).send(method, *args, &block)
          return
        else
          if response['messages'][0]['code'] == '102'
            results = Request.retrieve_first(@trophonius_model.layout_name)
            if results['messages'][0]['code'] != '0'
              Error.throw_error('102')
            else
              r_results = results['response']['data']
              ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
              query_keys = new_field_data.map { |q| q.keys.map(&:downcase) }.uniq
              Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), @trophonius_model.layout_name)
            end
          end
          Error.throw_error(response['messages'][0]['code'])
        end
      else
        r_results = response['response']['data']
        ret_val = RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields)
        r_results.each do |r|
          hash = @trophonius_model.build_result(r)
          ret_val << hash
        end
        @response = ret_val
        return @response.send(method, *args, &block)
      end
    end

    alias to_s inspect
  end
end
