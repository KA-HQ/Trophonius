module Trophonius
  module Trophonius::RedisManager
    def self.connect
      if ENV['REDIS_URL'] && ENV['REDIS_URL'] != ''
        @redis ||= Redis.new(url: ENV['REDIS_URL'])
      else
        @redis ||= Redis.new
      end
    end

    def self.key_exists?(key:)
      connect unless connectted?
      !(@redis.get(key).nil? || @redis.get(key).empty?)
    end

    def self.get_key(key:)
      connect unless connectted?
      @redis.get(key)
    end

    def self.set_key(key:, value:)
      connect unless connectted?
      @redis.set(key, value)
    end

    def self.connected?
      @redis.nil? == false && @redis.connected?
    end

    def self.disconnect
      @redis.disconnect!
    end
  end
end
