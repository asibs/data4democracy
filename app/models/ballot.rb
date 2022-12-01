class Ballot < ApplicationRecord
  belongs_to :election
  belongs_to :area

  has_many :candidates

  scope :ordered_by_date, -> { left_joins(:election).merge(Election.ordered_by_date) }
end
