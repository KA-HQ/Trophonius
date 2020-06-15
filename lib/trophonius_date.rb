class Date
  def to_fm
    self.strftime('%m/%d/%Y')
  end

  alias convert_to_fm to_fm
end
