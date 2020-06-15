class DateTime
  def self.parse_fm_timestamp(timestamp)
    DateTime.strptime(timestamp, '%m/%d/%Y %H:%M:%S')
  end
end
