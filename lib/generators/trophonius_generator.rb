require 'rails'

module Trophonius
  class InstallGenerator < ::Rails::Generators::Base
    namespace 'trophonius'

    class_option :host, type: :string, default: 'location_to.your_filemakerserver.com'
    class_option :database, type: :string, default: 'Name_of_your_database'

    source_root File.expand_path('../templates', __FILE__)

    desc 'add the config file'

    def copy_initializer_file
      @host = options['host']
      @database = options['database']
      create_file 'config/initializers/trophonius.rb',
                  "Trophonius.configure do |config|
  config.host = '#{@host}'
  config.database = '#{@database}'
  config.username = Rails.application.credentials.dig(:username) # (requires >= Rails 5.2) otherwise use old secrets
  config.password = Rails.application.credentials.dig(:password) # (requires >= Rails 5.2) otherwise use old secrets
  config.redis_connection = false # default false, true if you want to store the token in redis
  config.ssl = true # or false depending on whether https or http should be used
  # USE THE NEXT OPTION WITH CAUTION
  config.local_network = false # if true the ssl certificate will not be verified to allow for self-signed certificates
end"
    end
  end
end
