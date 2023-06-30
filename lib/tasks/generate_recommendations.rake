# frozen_string_literal: true
require 'csv'
require 'pry'

# USAGE: rails generate_recommendations[upcoming_elections_csv,past_election_results_csv]
task :generate_recommendations, %i[upcoming_elections_csv past_election_results_csv] => :environment do |_t, args|
  if args.upcoming_elections_csv.blank? || args.past_election_results_csv.blank?
    puts "USAGE: rails generate_recommendations[upcoming_elections_csv,past_election_results_csv]"
    puts "requires path to both an upcoming elections CSV file, and a past elections results CSV file"
    exit
  end

  # Add all past election results to a hash for easy lookup while we process upcoming elections
  puts "#{Time.now.iso8601} - Loading past elections data from #{args.past_election_results_csv}"
  past_election_results = {}
  SmarterCSV.process(args.past_election_results_csv, { chunk_size: 1_000 }) do |batch|
    batch.each do |past_election_row|
      council_slug = past_election_row[:council]
      ward_slug = past_election_row[:ward]

      past_election_results[council_slug] ||= {}
      past_election_results[council_slug][ward_slug] = past_election_row
    end
  end
  puts "#{Time.now.iso8601} - Finished loading past elections data"

  # For each upcoming election, make a recommendation and write to the output csv
  puts "#{Time.now.iso8601} - Reading upcoming elections from #{args.past_election_results_csv} to make recommendations"
  CSV.open('csvs/recommendations.csv', 'w') do |csv|
    csv << [
      'council_slug', 'ward_slug', 'council_name', 'ward_name', 'ward_gss', 'total_seats', 'seats_contested',
      'con_candidates', 'lab_candidates', 'lib_candidates', 'grn_candidates', 'other_candidates',
      'prev_election_date', 'prev_election_byelection?',
      'prev_con_votes', 'prev_con_candidates', 'prev_con_votes_per_candidate', 'prev_con_candidates_elected',
      'prev_lab_votes', 'prev_lab_candidates', 'prev_lab_votes_per_candidate', 'prev_lab_candidates_elected',
      'prev_libdem_votes', 'prev_libdem_candidates', 'prev_libdem_votes_per_candidate', 'prev_libdem_candidates_elected',
      'prev_green_votes', 'prev_green_candidates', 'prev_green_votes_per_candidate', 'prev_green_candidates_elected',
      'prev_other_votes', 'prev_other_candidates', 'prev_other_votes_per_candidate', 'prev_other_candidates_elected',
      'recommended_vote_1', 'recommended_vote_2', 'recommended_vote_3',
      'recommendation_public_notes', 'recommendation_internal_notes'
    ]

    SmarterCSV.process(args.upcoming_elections_csv, { chunk_size: 1_000 }) do |batch|
      batch.each do |election_row|
        council_slug = election_row[:council_slug]
        ward_slug = election_row[:ward_slug]
        previous_election = past_election_results.dig(council_slug, ward_slug)

        if previous_election.blank?
          puts "Couldn't find previous election for #{council_slug} #{ward_slug}"
          csv << [
            *election_row.values,
            '', '',         # date/byelection
            '', '', '', '', # CON data
            '', '', '', '', # LAB data
            '', '', '', '', # LIB data
            '', '', '', '', # GRN data
            '', '', '', '', # OTHER data
            '', '', '',     # recommendations 1-3
            '', "Couldn't find previous election results for #{council_slug} #{ward_slug}"
          ]
          next
        end

        rec_1, rec_2, rec_3, rec_public_notes, rec_internal_notes = make_recommendations(election_row, previous_election)

        csv << [
          *election_row.values,
          previous_election[:election_date], previous_election[:'byelection?'],
          previous_election[:con_votes], previous_election[:con_candidates],
          previous_election[:con_votes_per_candidate], previous_election[:con_candidates_elected],
          previous_election[:lab_votes], previous_election[:lab_candidates],
          previous_election[:lab_votes_per_candidate], previous_election[:lab_candidates_elected],
          previous_election[:libdem_votes], previous_election[:libdem_candidates],
          previous_election[:libdem_votes_per_candidate], previous_election[:libdem_candidates_elected],
          previous_election[:green_votes], previous_election[:green_candidates],
          previous_election[:green_votes_per_candidate], previous_election[:green_candidates_elected],
          previous_election[:other_votes], previous_election[:other_candidates],
          previous_election[:other_votes_per_candidate], previous_election[:other_candidates_elected],
          rec_1, rec_2, rec_3, rec_public_notes, rec_internal_notes
        ]
      end
    end
  end
  puts "#{Time.now.iso8601} - Finished reading upcoming elections and making recommendations"
end

def make_recommendations(election_row, previous_election)
  sorted_votes = sorted_votes_hash(previous_election)
  sorted_elected_candidates = sorted_elected_candidates_hash(previous_election)

  top_3_votes = Hash[*sorted_votes.first(3).flatten]

  if sorted_elected_candidates.keys != sorted_votes.keys.first(sorted_elected_candidates.length)
    return nil, nil, nil, nil, "Top 3 parties for votes & top 3 parties for elected candidates don't match"
  end

  # Top 3 parties by votes / candidates elected are the same if we're here
  if top_3_votes.keys[0] == 'CON'
    # Conservatives won the last election

    if known_progressives.include?(top_3_votes.keys[1])
      # Second place was a known-progressive
      return recommend_progressive_parties(election_row, sorted_votes)
    else
      # Second place not a known-progressive
      return nil, nil, nil, nil, "Last election won by a Conservative, 2nd place not a known progressive"
    end
  elsif known_progressives.include?(top_3_votes.keys[0])
    # A progressive party won the last election

    if top_3_votes.keys[1] == 'CON'
      # Second place was Conservative
      return recommend_progressive_parties(election_row, sorted_votes)
    else
      # Second place not Conservative

      if top_3_votes.values[0] >= (sorted_votes['CON'] * 1.5)
        # Winning progressive party got at least 50% more votes than Conservatives - v unlikely conservaties will win
        return nil, nil, nil, "Vote for your preferred progressive party - Conservatives unlikely to win here", "Last election won by a progressive, Conservatives not 2nd and winner had 50% more votes than Conservatives"
      else
        return recommend_progressive_parties(election_row, sorted_votes)
      end
    end
  else
    # A non-Conservative, not-known-progressive won the last election
    return nil, nil, nil, nil, "Last election won by a non-Conservative, but not a known progressive"
  end
end

def recommend_progressive_parties(election_row, sorted_votes)
  # Get sorted list of non-regressive parties (just Conservatives atm, but could add other rightwing parties)
  sorted_non_regressive = sorted_votes.reject { |k,v| known_regressives.include?(k) }

  seats_contested = election_row[:seats_contested].to_i
  recommendations = []
  public_notes = []
  internal_notes = []

  party_index = 0

  while recommendations.length < seats_contested && party_index < sorted_non_regressive.size
    current_party = sorted_non_regressive.keys[party_index]

    # Stop adding recommendations as soon as we hit a party which might not be progressive
    break unless known_progressives.include?(current_party)

    current_party_votes = sorted_non_regressive.values[party_index]
    next_party_votes = sorted_non_regressive.values[party_index+1] || 0

    if current_party_votes >= next_party_votes * 1.1
      # Current progressive party got 10% more votes than next progressive party_name
      # Add however many candidates they are standing to the recommendations list
      current_party_candidates = election_row["#{current_party.downcase}_candidates".to_sym]

      current_party_candidates.times { recommendations << current_party }

      if current_party_candidates < seats_contested
        internal_notes << "Recommending #{current_party}, but only standing #{current_party_candidates} candidates out of #{seats_contested} contested seats."
      end
    else
      # Current progressive party and next place are close - don't make a call
      next_party = sorted_non_regressive.keys[party_index+1]

      internal_notes << "Party #{current_party} and #{next_party} are within 10% of each other, not recommending either"
      break
    end

    party_index += 1
  end

  # Take the top X recommendations only (loop above could've added more than X)
  recommendations = recommendations[0..seats_contested-1]

  # Ensure there are 3 (the CSV requires 3 columns)
  (3-seats_contested).times { recommendations << nil }

  return recommendations[0], recommendations[1], recommendations[2], public_notes.join('\n'), internal_notes.join('\n')
end

def sorted_votes_hash(previous_election)
  # Sort by value (votes) descending
  # if draw, sort by key (party) to ensure predictable / deterministic behaviour
  {
    'CON' => parse_float(previous_election[:con_votes_per_candidate]),
    'LAB' => parse_float(previous_election[:lab_votes_per_candidate]),
    'LIB' => parse_float(previous_election[:libdem_votes_per_candidate]),
    'GRN' => parse_float(previous_election[:green_votes_per_candidate]),
    'OTHER' => parse_float(previous_election[:other_votes_per_candidate])
  }.sort_by { |k,v| [-v,k] }.to_h
end

def sorted_elected_candidates_hash(previous_election)
  # Sort by value (# candidates elected) descending
  # if draw, sort by key (party) to ensure predictable / deterministic behaviour
  {
    'CON' => parse_float(previous_election[:con_candidates_elected]),
    'LAB' => parse_float(previous_election[:lab_candidates_elected]),
    'LIB' => parse_float(previous_election[:libdem_candidates_elected]),
    'GRN' => parse_float(previous_election[:green_candidates_elected]),
    'OTHER' => parse_float(previous_election[:other_candidates_elected])
  }.reject { |k,v| v.zero? || v.nil? }.sort_by { |k,v| [-v,k] }.to_h
end

def known_progressives
  ['LAB', 'LIB', 'GRN']
end

def known_regressives
  ['CON']
end

def parse_float(string)
  string.to_f
rescue
  0.0
end
