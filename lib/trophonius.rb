require 'connectors/database_request'
require 'connectors/connection_manager'
require 'model'
require 'config'
require 'date'
require 'time'
require 'date_time'

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
