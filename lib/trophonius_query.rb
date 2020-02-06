require "json"
require "trophonius_config"
require "trophonius_record"
require "trophonius_recordset"
require "trophonius_error"

module Trophonius
  class Trophonius::Query
    attr_reader :response

    ##
    # Creates a new instance of the Trophonius::Query class
    # 
    # @param [Trophonius::Model] base model for the new query
    # @return [Trophonius::Query] new instance of Trophonius::Query
    def initialize(trophonius_model:)
      @response = RecordSet.new(trophonius_model.layout_name, trophonius_model.non_modifiable_fields)
      @trophonius_model = trophonius_model
    end

    ##
    # Returns the current query, creates an empty query if no current query exists
    #
    # @return [Array[Hash]] array representing the FileMaker find request
    def build_query
      @current_query ||= [{}]
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
      args[1].current_query.build_query << args[0].merge!({omit: true})
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
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{@trophonius_model.layout_name}/_find")
      new_field_data = @current_query.map { |q| {} }
      if @trophonius_model.translations.keys.empty?
        @trophonius_model.create_translations
      end
      @current_query.each_with_index do |query, index|
        query.keys.each do |k|
          if @trophonius_model.translations.keys.include?(k.to_s)
            new_field_data[index].merge!({"#{@trophonius_model.translations[k.to_s]}" => query[k].to_s})
          else
            new_field_data[index].merge!({"#{k}" => query[k].to_s})
          end
        end
      end
      body = {query: new_field_data, limit:"100000"}.to_json
      response = Request.make_request(url, "Bearer #{Request.get_token}", "post", body)
      if response["messages"][0]["code"] != "0"
        if response["messages"][0]["code"] == "101" || response["messages"][0]["code"] == "401"
          RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields).send(method, *args, &block)
          return
        else
          Error.throw_error(response["messages"][0]["code"])
        end
      else
        r_results = response["response"]["data"]
        ret_val = RecordSet.new(@trophonius_model.layout_name, @trophonius_model.non_modifiable_fields)
        r_results.each do |r|
          hash = @trophonius_model.build_result(r)
          ret_val << hash
        end
        @response = ret_val
        return @response.send(method, *args, &block)
      end
    end
    
    alias_method :to_s, :inspect
  end
end