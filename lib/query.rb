require 'json'
require 'config'
require 'record'
require 'recordset'
require 'error'

module Trophonius
  class Query
    attr_reader :response
    attr_accessor :presort_script, :presort_scriptparam, :prerequest_script, :prerequest_scriptparam, :post_request_script, :post_request_scriptparam

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
      @presort_script = ''
      @presort_scriptparam = ''
      @prerequest_script = ''
      @prerequest_scriptparam = ''
      @post_request_script = ''
      @post_request_scriptparam = ''
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
      @current_sort ||= []
    end

    def inspect
      @current_query
    end

    ##
    # Returns the current portal limits
    #
    # @return [Hash] Hash representing the portal limits
    def build_portal_limits
      @portal_limits ||= {}
    end

    ##
    # Adds a portal limit to the request
    #
    # @param [args] arguments containing a Hash with the format {portalName: requiredLimit}
    # @return [Trophonius::Model] updated base model
    def set_portal_limits(args)
      args[1].current_query.build_portal_limits.merge!(args[0])
      args[1]
    end

    ##
    # Adds a post-request script to the request
    #
    # @param [args] arguments containing a String with the name of the script
    # @return [Trophonius::Model] updated base model
    def set_post_request_script(args)
      args[1].current_query.post_request_script = args[0]
      args[1]
    end

    ##
    # Adds a post-request scriptparameter to the request
    #
    # @param [args] arguments containing a String with the name of the scriptparameter
    # @return [Trophonius::Model] updated base model
    def set_post_request_script_param(args)
      args[1].current_query.post_request_scriptparam = args[0]
      args[1]
    end

    ##
    # Adds a pre-request script to the request
    #
    # @param [args] arguments containing a String with the name of the script
    # @return [Trophonius::Model] updated base model
    def set_prerequest_script(args)
      args[1].current_query.prerequest_script = args[0]
      args[1]
    end

    ##
    # Adds a pre-request scriptparameter to the request
    #
    # @param [args] arguments containing a String with the name of the scriptparameter
    # @return [Trophonius::Model] updated base model
    def set_prerequest_script_param(args)
      args[1].current_query.prerequest_scriptparam = args[0]
      args[1]
    end

    ##
    # Adds a pre-sort script to the request
    #
    # @param [args] arguments containing a String with the name of the script
    # @return [Trophonius::Model] updated base model
    def set_presort_script(args)
      args[1].current_query.presort_script = args[0]
      args[1]
    end

    ##
    # Adds a pre-request scriptparameter to the request
    #
    # @param [args] arguments containing a String with the name of the scriptparameter
    # @return [Trophonius::Model] updated base model
    def set_presort_script_param(args)
      args[1].current_query.presort_scriptparam = args[0]
      args[1]
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
      @offset = (((args[0] * args[1]) - args[1]) + 1)
      @limit = args[1]
      args[2]
    end

    ##
    # Adds a sort request to the original query, resulting in an "sorted" query
    #
    # @param [args] arguments containing a Hash containing the FileMaker sort request, and the base model object for the query
    # @return [Trophonius::Model] updated base model
    def sort(args)
      @trophonius_model.create_translations if @trophonius_model.translations.keys.empty?
      args[0].each do |key, value|
        args[1].current_query.build_sort << if @trophonius_model.translations.key?(key.to_s)
                                              { fieldName: "#{@trophonius_model.translations[key.to_s]}", sortOrder: "#{value}" }
                                            else
                                              { fieldName: "#{key}", sortOrder: "#{value}" }
                                            end
      end
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
      url = "/layouts/#{@trophonius_model.layout_name}/_find"
      new_field_data = @current_query.map { |_q| {} }

      @trophonius_model.create_translations if @trophonius_model.translations.keys.empty?
      @current_query.each_with_index do |query, index|
        query.each_key do |k|
          if @trophonius_model.translations.key?(k.to_s)
            new_field_data[index].merge!(@trophonius_model.translations[k.to_s].to_s => query[k].to_s)
          else
            new_field_data[index].merge!(k.to_s => query[k].to_s)
          end
        end
      end
      body = if @offset.nil? || @limit.nil? || @offset == '' || @limit == '' || @offset == 0 || @limit == 0
               @current_sort.nil? ? { query: new_field_data, limit: '100000' } : { query: new_field_data, sort: @current_sort, limit: '100000' }
             elsif @current_sort.nil?
               { query: new_field_data, limit: @limit.to_s, offset: @offset.to_s }
             else
               { query: new_field_data, sort: @current_sort, limit: @limit.to_s, offset: @offset.to_s }
             end

      if @post_request_script.present?
        body.merge!(script: @post_request_script)
        body.merge!('script.param' => @post_request_scriptparam) if @post_request_scriptparam.present?
      end

      if @prerequest_script.present?
        body.merge!('script.prerequest' => @prerequest_script)
        body.merge!('script.prerequest.param' => @prerequest_scriptparam) if @prerequest_scriptparam.present?
      end

      if @presort_script.present?
        body.merge!('script.presort' => @presort_script)
        body.merge!('script.presort.param' => @presort_scriptparam) if @presort_scriptparam.present?
      end

      if @portal_limits
        portal_hash = { portal: @portal_limits.map { |portal_name, _limit| portal_name } }
        body.merge!(portal_hash)
        @portal_limits.each { |portal_name, limit| body.merge!({ "limit.#{portal_name}" => limit.to_s }) }
      end

      body = body.to_json
      response = DatabaseRequest.make_request(url, 'post', body)

      if response['messages'][0]['code'] == '0'
        r_results = response['response']['data']
        ret_val = RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields)

        r_results.each do |r|
          r['fieldData'].merge!('post_request_script_result' => response['response']['scriptResult']) if response['response']['scriptResult']

          if response['response']['scriptResult.presort']
            r['fieldData'].merge!('presort_script_result' => response['response']['scriptResult.presort'])
          end

          if response['response']['scriptResult.prerequest']
            r['fieldData'].merge!('prerequest_script_result' => response['response']['scriptResult.prerequest'])
          end

          r['fieldData'].merge!('post_request_script_error' => response['response']['scriptError']) if response['response']['scriptError']

          r['fieldData'].merge!('presort_script_error' => response['response']['scriptError.presort']) if response['response']['scriptError.presort']

          if response['response']['scriptError.prerequest']
            r['fieldData'].merge!('prerequest_script_error' => response['response']['scriptError.prerequest'])
          end

          hash = @trophonius_model.build_result(r)
          ret_val << hash
        end
        @response = ret_val
        @response.send(method, *args, &block)
      elsif response['messages'][0]['code'] == '101' || response['messages'][0]['code'] == '401'
        RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields).send(method, *args, &block)

      else
        if response['messages'][0]['code'] == '102'
          results = DatabaseRequest.retrieve_first(@trophonius_model.layout_name)
          if results['messages'][0]['code'] == '0'
            r_results = results['response']['data']
            ret_val = r_results.empty? ? Error.throw_error('102') : r_results[0]['fieldData']
            query_keys = new_field_data.map { |q| q.keys.map(&:downcase) }.uniq
            Error.throw_error('102', (query_keys - ret_val.keys.map(&:downcase)).flatten.join(', '), @trophonius_model.layout_name)
          else
            Error.throw_error('102')
          end
        end
        Error.throw_error(response['messages'][0]['code'])
      end
    end

    alias to_s inspect
  end
end
