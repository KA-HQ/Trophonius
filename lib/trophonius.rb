require 'trophonius_request'
require 'trophonius_model'
require 'trophonius_config'
require 'trophonius_date'
require 'trophonius_time'

module Trophonius # :nodoc:
  def self.configuration
    Ethon.logger = Logger.new(nil)
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.config
    @configuration
  end

  private
end
