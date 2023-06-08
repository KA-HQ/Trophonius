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
