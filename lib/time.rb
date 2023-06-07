class Time
  def to_fm
    self.strftime('%m-%d-%Y %H:%M:%S')
  end
  alias convert_to_fm to_fm
end
