class Election < ApplicationRecord
  belongs_to :election_type

  has_many :ballots

  scope :ordered_by_date, -> { order(election_date: :asc) }
end
