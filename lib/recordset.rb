require 'json'
require 'config'
require 'model'
require 'connectors/connection'

module Trophonius
  # A RecordSet contains all records, as Record, retrieved from the FileMaker database
  class RecordSet < Array
    attr_accessor :result_count, :layout_name, :non_modifiable_fields, :records

    class EmptyParameterError < ArgumentError; end # :nodoc:

    ##
    # Initializes a new RecordSet
    #
    # @param [String] l_name: name of the FileMaker layout
    #
    # @param [Array] nmf: names of the fields that cannot be modified (calculation fields etc.)
    def initialize(l_name, nmf)
      self.layout_name = l_name
      self.non_modifiable_fields = nmf
      self.records = []
    end

    def <<(data)
      records << data
      super
    end

    ##
    # This method allows to chain where statements
    #
    # @param [Hash] fielddata: hash containing the query
    #
    # @return [RecordSet] the records where the statement holds
    def where(fielddata)
      raise EmptyParameterError.new, 'No requested data to find' if fielddata.nil? || fielddata.empty?

      temp = Trophonius::Model
      temp.config layout_name: layout_name, non_modifiable_fields: non_modifiable_fields
      temp.where(fielddata)
    end

    ##
    # This method chops the RecordSet up in parts.
    #
    # @param [Integer] page: the current page
    #
    # @param [Integer] records_per_page: the amount of records on the page
    #
    # @return [RecordSet] the records in the range ((page * records_per_page) - records_per_page) + 1 until ((page * records_per_page) - records_per_page) + 1 + records_per_page
    def paginate(page, records_per_page)
      offset = ((page * records_per_page) - records_per_page)
      records[offset...offset + records_per_page]
    end
  end
end
