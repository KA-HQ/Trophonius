require 'time'
require 'date_time'
require 'date'

require 'fm_time'
require 'fm_date_time'
require 'fm_date'

require 'connectors/database_request'
require 'connectors/connection_manager'
require 'model'
require 'config'

module Trophonius # :nodoc:
  def self.configuration
    Ethon.logger = Logger.new(nil)
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
    @connection_manager ||= ConnectionManager.new
    @configuration
  end

  def self.connection_manager
    @connection_manager
  end

  def self.config
    @configuration
  end
end
