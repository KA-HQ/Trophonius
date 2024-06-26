require 'date'
require 'time'

class Time
  def to_fm
    strftime('%m-%d-%Y %H:%M:%S')
  end

  def self.from_fm(time)
    Time.strptime(time, '%m/%d/%Y %H:%M:%S')
  end

  alias convert_to_fm to_fm
end
