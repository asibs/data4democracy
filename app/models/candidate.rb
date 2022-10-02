class Candidate < ApplicationRecord
  belongs_to :ballot
  belongs_to :person
  belongs_to :party, optional: true
end
