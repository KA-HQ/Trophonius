module Trophonius
  module DebugPrinter
    def self.print_debug(open_close_message, message)
      return unless Trophonius.config.debug == true

      puts "======== #{open_close_message} ========"
      puts message
      puts "======== #{open_close_message} ========"
    end
  end
end
