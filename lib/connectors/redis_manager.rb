module Trophonius
  # the RedisManager module is used to create a (single) connection to a redis store.
  module Trophonius::RedisManager
    def self.connect
      return unless Trophonius.config.redis_connection

      redis_url = ENV.fetch('REDIS_URL')
      options = {}
      options.merge!(url: redis_url) if redis_url && redis_url != ''
      options.merge!(ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }) if Trophonius.config.redis_no_verify
      @redis ||= Redis.new(options)

      nil
    end

    ##
    # Checks whether the given key exists
    #
    # @param [String] key: the key to check
    # @return [Boolean] true or false depending on whether the key exists in the redis store or not
    def self.key_exists?(key:)
      connect unless connected?
      !(@redis.get(key).nil? || @redis.get(key).empty?)
    end

    ##
    # Get the value corresponding with the key
    #
    # @param [String] key: the key to find
    # @return [String] the value corresponding with the key
    def self.get_key(key:)
      connect unless connected?
      @redis.get(key)
    end

    ##
    # Set the value corresponding with a key
    #
    # @param [String] key: the key to store in redis
    # @param [any] value: the value for the key
    # @return [String] the value corresponding with the key
    def self.set_key(key:, value:)
      connect unless connected?
      @redis.set(key, value)
    end

    ##
    # Checks whether we are connected to redis
    #
    # @return [Boolean] true or false depending on whether a connection to redis has been established
    def self.connected?
      @redis.nil? == false && @redis.connected?
    end

    ##
    # Disconnects from redis as quickly and as silently as possible
    #
    # @return [NilClass] nil
    def self.disconnect
      @redis.disconnect!
    end
  end
end
