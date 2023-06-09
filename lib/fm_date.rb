class Date
  def to_fm
    strftime('%m/%d/%Y')
  end

  def self.from_fm(fm_date)
    Date.strptime(fm_date, '%m/%d/%Y')
  end

  alias convert_to_fm to_fm
end
