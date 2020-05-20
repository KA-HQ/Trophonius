module Trophonius
  # the RedisManager module is used to create a (single) connection to a redis store.
  module Trophonius::RedisManager
    def self.connect
      if Trophonius.config.redis_connection
        if ENV['REDIS_URL'] && ENV['REDIS_URL'] != ''
          @redis ||= Redis.new(url: ENV['REDIS_URL'])
        else
          @redis ||= Redis.new
        end
      end
      return nil
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
