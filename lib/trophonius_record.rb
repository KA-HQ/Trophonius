require 'json'
require 'trophonius_config'

module Trophonius
  # This class will hold a singular record
  #
  # A Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Trophonius::Record < Hash
    attr_accessor :id, :layout_name, :modifiable_fields, :modified_fields

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

    ##
    # Saves the last changes made to the Record to FileMaker.
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def save
      url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{id}")
      body = "{\"fieldData\": #{modified_fields.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      if response['messages'][0]['code'] != '0'
        Error.throw_error(response['messages'][0]['code'])
      else
        return true
      end
    end

    ##
    # Deletes the corresponding record from FileMaker
    # Throws a FileMaker error if save failed
    #
    # @return [True] if successful
    def delete
      url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{id}")
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'delete', '{}')
      if response['messages'][0]['code'] != '0'
        Error.throw_error(response['messages'][0]['code'])
      else
        return true
      end
    end

    ##
    # Changes and saves the corresponding record in FileMaker
    # Throws a FileMaker error if save failed
    #
    # @param [Hash] fieldData: Fields to be changed and data to fill the fields with
    #
    # @return [True] if successful
    def update(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? 's' : ''}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{layout_name}/records/#{id}")
      fieldData.keys.each do |field|
        modifiable_fields[field] = fieldData[field]
      end
      body = "{\"fieldData\": #{fieldData.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", 'patch', body)
      if response['messages'][0]['code'] != '0'
        Error.throw_error(response['messages'][0]['code'])
      else
        return true
      end
    end
  end
end
