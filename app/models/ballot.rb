class Ballot < ApplicationRecord
  belongs_to :election
  belongs_to :area
end
