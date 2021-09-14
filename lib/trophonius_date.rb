class Date
  def to_fm
    self.strftime('%m/%d/%Y')
  end

  def self.from_fm(fm_date)
    Date.strptime(self, '%m/%d/%Y')
  end

  alias convert_to_fm to_fm
  alias convert_from_fm from_fm
end
