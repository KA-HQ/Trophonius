module Trophonius
  class ConnectionManager
    def initialize
      @connections = {}
      Trophonius.config.pool_size.times do
        connection = Connection.new
        @connections[connection.id] = { connection: connection, queue: [] }
      end
    end

    def enqueue(id)
      connection = @connections.values.min_by { |c| c[:queue].length }
      connection[:queue].push(id)
      puts "in,#{connection[:connection].id},#{connection[:connection].token},#{connection[:queue].length}" if Trophonius.config.debug == true
      auth_header_bearer(connection[:connection].id)
    end

    def dequeue(id)
      connection = @connections.values.find { |c| c[:queue].include?(id) }
      connection[:queue].delete_if { |q_id| q_id == id }
      puts "out,#{connection[:connection].id},#{connection[:connection].token},#{connection[:queue].length}" if Trophonius.config.debug == true
      nil
    end

    private

    def auth_header_bearer(id)
      "Bearer #{@connections.dig(id, :connection).token}"
    end
  end
end
