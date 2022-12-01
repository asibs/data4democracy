class Area < ApplicationRecord
  belongs_to :area_type

  has_one :area_boundary

  has_many :ballots
end
