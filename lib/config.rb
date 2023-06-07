require 'active_support/configurable'
require 'ethon'

module Trophonius
  class Configuration # :nodoc:
    include ActiveSupport::Configurable

    config_accessor(:host) { '127.0.0.1' }
    config_accessor(:port) { 0 }
    config_accessor(:database) { '' }
    config_accessor(:external_name) { '' }
    config_accessor(:external_username) { '' }
    config_accessor(:external_password) { '' }
    config_accessor(:username) { 'Admin' }
    config_accessor(:password) { '' }
    config_accessor(:ssl) { true }
    config_accessor(:fm_18) { true }
    config_accessor(:count_result_script) { '' }
    config_accessor(:layout_name) { '' }
    config_accessor(:non_modifiable_fields) { [] }
    config_accessor(:translations) { {} }
    config_accessor(:has_many_relations) { {} }
    config_accessor(:belongs_to_relations) { {} }
    config_accessor(:local_network) { false }
    config_accessor(:redis_connection) { false }
    config_accessor(:pool_size) { 5 }
    config_accessor(:debug) { false }
  end
end
