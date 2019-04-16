require "json"
require "trophonius_config"

module Trophonius
  # this class will hold a singular record
  # the idea is that a Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Trophonius::Record < Hash
    attr_accessor :id, :layout_name, :modifiable_fields

    def initialize
      @modifiable_fields = {}
    end

    def []=(field, new_val)
      self.modifiable_fields[field] = new_val
      super
    end

    def save
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{self.layout_name}/records/#{self.id}")
      body = "{\"fieldData\": #{self.modifiable_fields.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "patch", body)
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        return true
      end
    end

    def delete
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{self.layout_name}/records/#{self.id}")
      response = Request.make_request(url, "Bearer #{Request.get_token}", "delete", "{}")
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        return true
      end
    end

    def update(fieldData)
      url = URI("http#{Trophonius.config.ssl == true ? "s" : ""}://#{Trophonius.config.host}/fmi/data/v1/databases/#{Trophonius.config.database}/layouts/#{self.layout_name}/records/#{self.id}")
      fieldData.keys.each do |field|
        self.modifiable_fields[field] = fieldData[field]
      end
      body = "{\"fieldData\": #{fieldData.to_json}}"
      response = Request.make_request(url, "Bearer #{Request.get_token}", "patch", body)
      if response["messages"][0]["code"] != "0"
        Error.throw_error(response["messages"][0]["code"])
      else
        return true
      end
    end
  end
end
