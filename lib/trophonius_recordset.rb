require "json"
require "trophonius_config"
require "trophonius_model"
require "trophonius_connection"

module Trophonius
  # this class will hold a list of records
  # the idea is that a Record is contained in a RecordSet and has methods to retrieve data from the fields inside the Record-hash
  class Trophonius::RecordSet < Array
    attr_accessor :result_count, :layout_name, :non_modifiable_fields, :records

    class EmptyParameterError < ArgumentError; end

    def initialize(l_name, nmf)
      self.layout_name = l_name
      self.non_modifiable_fields = nmf
      self.records = []
    end

    def <<(data)
      self.records << data
      super
    end

    def where(fielddata)
      raise EmptyParameterError.new(), "No requested data to find" if fielddata.nil? || fielddata.empty?
      temp = Trophonius::Model
      temp.config layout_name: self.layout_name, non_modifiable_fields: self.non_modifiable_fields
      retval = temp.where(fielddata)
      retval
    end

    def paginate(page, records_per_page)
      offset = ((page * records_per_page) - records_per_page) + 1
      return self.records[offset...offset + records_per_page]
    end
  end
end
