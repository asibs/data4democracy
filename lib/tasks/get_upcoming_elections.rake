# frozen_string_literal: true
require 'csv'
require 'pry'

# USAGE: rails get_upcoming_elections
task :get_upcoming_elections => :environment do |_t, args|
  dc_elections_api = DemocracyClub::DcElectionsApi.new
  dc_api = DemocracyClub::DcApi.new

  # First iterate through each parent (council) election, and get all child elections
  ward_election_ids = []
  dc_elections_api.elections(
    election_date: '2023-05-04',
    election_id_regex: 'local\.[^\.]*\.2023'
  ).each do |parent_election_page|
    parent_election_page.each do |parent_election_json|
      ward_election_ids << parent_election_json['children']
    end
  end
  ward_election_ids.flatten!

  puts "Found #{ward_election_ids.length} wards with elections - writing CSV..."

  CSV.open("csvs/upcoming_elections.csv", 'w') do |csv|
    # csv << [
    #   'council_slug', 'ward_slug', 'council_name', 'ward_name', 'ward_gss',
    #   'total_seats', 'seats_contested'
    # ]

    # New version with candidate totals
    csv << [
      'council_slug', 'ward_slug', 'council_name', 'ward_name', 'ward_gss', 'total_seats', 'seats_contested',
      'con_candidates', 'lab_candidates', 'lib_candidates', 'grn_candidates', 'other_candidates'
    ]

    ward_election_ids.each_with_index do |id, index|
      puts "#{Time.now.iso8601} - Processing election #{index} of #{ward_election_ids.length}" if index % 100 == 0

      # election_json = dc_elections_api.election(election_id: id)
      # write_election(election_json, csv)

      # New version with candidate totals
      election_json = dc_elections_api.election(election_id: id)
      ballot_json = dc_api.ballot(ballot_paper_id: id)
      write_election_with_candidate_counts(election_json, ballot_json, csv)
    end
  end
end

def write_election(election_json, csv)
  council_slug = election_json['organisation']['slug']
  council_name = election_json['organisation']['common_name']
  ward_slug = election_json['division']['slug']
  ward_name = election_json['division']['name']
  ward_gss = election_json['division']['official_identifier']
  total_seats = election_json['division']['seats_total']
  seats_contested = election_json['seats_contested']

  csv << [
    council_slug, ward_slug, council_name, ward_name, ward_gss, total_seats, seats_contested
  ]
end

def write_election_with_candidate_counts(election_json, ballot_json, csv)
  council_slug = election_json['organisation']['slug']
  council_name = election_json['organisation']['common_name']
  ward_slug = election_json['division']['slug']
  ward_name = election_json['division']['name']
  ward_gss = election_json['division']['official_identifier']
  total_seats = election_json['division']['seats_total']
  seats_contested = election_json['seats_contested']
  party_candidate_counts = count_party_candidacies(ballot_json)

  csv << [
    council_slug, ward_slug, council_name, ward_name, ward_gss, total_seats, seats_contested,
    party_candidate_counts['CON'], party_candidate_counts['LAB'], party_candidate_counts['LIB'],
    party_candidate_counts['GRN'], party_candidate_counts['OTHER']
  ]
end

def count_party_candidacies(ballot_json)
  party_mappings = {
    'Conservative and Unionist Party' => 'CON',
    'Labour Party' => 'LAB',
    'Labour and Co-operative Party' => 'LAB',
    'Liberal Democrats' => 'LIB',
    'Green Party' => 'GRN'
  }

  parties = ballot_json['candidacies'].map do |candidate_json|
    party_name = candidate_json['party']['name']
    normalised_party_name = party_mappings[party_name]

    normalised_party_name || 'OTHER'
  end

  parties.reduce(Hash.new { 0 }) do |results_hash, party|
    results_hash[party] += 1

    results_hash
  end
end
