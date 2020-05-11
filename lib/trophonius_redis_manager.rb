module Trophonius
  class Trophonius::RedisManager
    def initialize
      if ENV['REDIS_URL'] && ENV['REDIS_URL'] != ''
        @redis ||= Redis.new(url: ENV['REDIS_URL'])
      else
        @redis ||= Redis.new
      end
    end

    def key_exists?(key:)
      !(@redis.get(key).nil? || @redis.get(key).empty?)
    end

    def get_key(key:)
      @redis.get(key)
    end

    def set_key(key:, value:)
      @redis.set(key, value)
    end

    def disconnect
      @redis.disconnect!
    end
  end
end
