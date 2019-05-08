require 'trophonius_request'
require 'trophonius_model'
require 'trophonius_config'

module Trophonius # :nodoc:
  def self.configuration
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
