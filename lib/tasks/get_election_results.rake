# frozen_string_literal: true
require 'csv'

# USAGE: rails get_election_results[local,2022-01-01,2022-03-01]
task :get_election_results, %i[type from_date to_date] => :environment do |_t, args|
  args.with_defaults(type: 'local', from_date: '2000-01-01', to_date: '2050-01-01')

  from_date = Date.parse(args.from_date)
  to_date = Date.parse(args.to_date)

  # Hash of election_type -> area -> subarea -> date -> results
  ballots = {}

  DemocracyClub::DcApi.new.ballots(
    election_type: args.type,
    election_date_after: from_date,
    election_date_before: to_date,
    has_results: true
  ).each_with_index do |page, i|
    puts "#{Time.now.iso8601} - Processing page #{i} of results" if i % 100 == 0

    page.each do |ballot_json|
      add_ballot(ballots, ballot_json)
    end
  end

  write_high_fidelity_csv(ballots)
  write_mid_fidelity_csv(ballots)
  write_low_fidelity_csv(ballots)
end

def add_ballot(ballots, ballot_json)
  ballot_paper_data = parse_ballot_paper_id(ballot_json['ballot_paper_id'])

  return unless ballot_paper_data.present?

  type = ballot_paper_data[:type]
  area = ballot_paper_data[:area]
  subarea = ballot_paper_data[:subarea]
  date = ballot_paper_data[:date]

  ballots[type] ||= {}
  ballots[type][area] ||= {}
  ballots[type][area][subarea] ||= {}
  ballots[type][area][subarea][date] = {
    ballot_paper_id: ballot_json['ballot_paper_id'],
    election: ballot_json['election'],
    post: ballot_json['post'],
    candidacies: ballot_json['candidacies'],
    byelection: ballot_paper_data[:byelection]
  }
end

def parse_ballot_paper_id(ballot_paper_id)
  # Ballot paper ids take the format:
  # {type}.{area}.{subarea}.{date}    - for normal scheduled elections
  # {type}.{area}.{subarea}.by.{date} - for by-elections
  if /^([a-z]+)\.([a-z-]+)\.([a-z-]+)\.(by\.)?([0-9-]+)$/ =~ ballot_paper_id
    return {
      type: $1,
      area: $2,
      subarea: $3,
      byelection: $4.present?,
      date: Date.parse($5)
    }
  else
    puts "Unrecognised format for ballot_paper_id: #{ballot_paper_id}"
  end
end

def votes_per_candidate(votes, candidates)
  if candidates == 0
    return 0.0
  else
    return votes.to_f / candidates
  end
end

def write_high_fidelity_csv(ballots)
  # 1 row per candidate for every election
  CSV.open('csvs/high-fidelity.csv', 'w') do |csv|
    csv << [
      'election_type', 'council', 'ward', 'election_date', 'byelection?',
      'candidate_name', 'party', 'votes', 'elected?'
    ]

    ballots.keys.each do |election_type|
      ballots[election_type].keys.each do |area|
        ballots[election_type][area].keys.each do |sub_area|
          most_recent_date = ballots[election_type][area][sub_area].keys.sort.last

          ballot = ballots[election_type][area][sub_area][most_recent_date]

          ballot[:candidacies].each do |candidate|
            csv << [
              election_type, area, sub_area, most_recent_date, ballot[:byelection],
              candidate.dig('person', 'name'), candidate.dig('party', 'name'),
              candidate.dig('result', 'num_ballots'), candidate.dig('result', 'elected')
            ]
          end
        end
      end
    end
  end
end

def write_mid_fidelity_csv(ballots)
  # 1 row per election per party (candidates grouped by party)
  CSV.open('csvs/mid-fidelity.csv', 'w') do |csv|
    csv << [
      'election_type', 'council', 'ward', 'election_date', 'byelection?',
      'party', 'votes', 'candidates', 'votes_per_candidate', 'candidates_elected'
    ]

    ballots.keys.each do |election_type|
      ballots[election_type].keys.each do |area|
        ballots[election_type][area].keys.each do |sub_area|
          most_recent_date = ballots[election_type][area][sub_area].keys.sort.last

          ballot = ballots[election_type][area][sub_area][most_recent_date]

          results_by_party = ballot[:candidacies].reduce({}) do |results, candidate|
            party = candidate['party']['name']

            results[party] ||= { votes: 0, candidates: 0, candidates_elected: 0 }
            results[party][:votes] += candidate.dig('result', 'num_ballots') || 0
            results[party][:candidates] += 1
            results[party][:candidates_elected] += (candidate.dig('result', 'elected') ? 1 : 0)

            results
          end

          results_by_party.each do |party, results|
            csv << [
              election_type, area, sub_area, most_recent_date, ballot[:byelection],
              party, results[:votes], results[:candidates],
              (results[:votes] / results[:candidates].to_f), results[:candidates_elected]
            ]
          end
        end
      end
    end
  end
end

def write_low_fidelity_csv(ballots)
  # 1 row per election (columns for each party, candidates grouped by party)
  party_names_map = {
    'Conservative and Unionist Party' => 'con',
    'Labour Party' => 'lab',
    'Labour and Co-operative Party' => 'lab',
    'Liberal Democrats' => 'libdem',
    'Green Party' => 'green'
  }

  default_results_by_party = {
    'con' => { votes: 0, candidates: 0, candidates_elected: 0 },
    'lab' => { votes: 0, candidates: 0, candidates_elected: 0 },
    'libdem' => { votes: 0, candidates: 0, candidates_elected: 0 },
    'green' => { votes: 0, candidates: 0, candidates_elected: 0 },
    'other' => { votes: 0, candidates: 0, candidates_elected: 0 }
  }

  other_parties = []

  CSV.open('csvs/low-fidelity.csv', 'w') do |csv|
    csv << [
      'election_type', 'council', 'ward', 'election_date', 'byelection?',
      'con_votes', 'con_candidates', 'con_votes_per_candidate', 'con_candidates_elected',
      'lab_votes', 'lab_candidates', 'lab_votes_per_candidate', 'lab_candidates_elected',
      'libdem_votes', 'libdem_candidates', 'libdem_votes_per_candidate', 'libdem_candidates_elected',
      'green_votes', 'green_candidates', 'green_votes_per_candidate', 'green_candidates_elected',
      'other_votes', 'other_candidates', 'other_votes_per_candidate', 'other_candidates_elected'
    ]

    ballots.keys.each do |election_type|
      ballots[election_type].keys.each do |area|
        ballots[election_type][area].keys.each do |sub_area|
          most_recent_date = ballots[election_type][area][sub_area].keys.sort.last

          ballot = ballots[election_type][area][sub_area][most_recent_date]

          results_by_party = ballot[:candidacies].reduce(default_results_by_party.deep_dup) do |results, candidate|
            original_party_name = candidate['party']['name']
            if party_names_map.keys.include?(original_party_name)
              party = party_names_map[original_party_name]
            else
              other_parties << party
              party = 'other'
            end

            results[party][:votes] += candidate.dig('result', 'num_ballots') || 0
            results[party][:candidates] += 1
            results[party][:candidates_elected] += (candidate.dig('result', 'elected') ? 1 : 0)

            results
          end

          csv << [
            election_type, area, sub_area, most_recent_date, ballot[:byelection],
            results_by_party['con'][:votes],
            results_by_party['con'][:candidates],
            votes_per_candidate(results_by_party['con'][:votes], results_by_party['con'][:candidates]),
            results_by_party['con'][:candidates_elected],
            results_by_party['lab'][:votes],
            results_by_party['lab'][:candidates],
            votes_per_candidate(results_by_party['lab'][:votes], results_by_party['lab'][:candidates]),
            results_by_party['lab'][:candidates_elected],
            results_by_party['libdem'][:votes],
            results_by_party['libdem'][:candidates],
            votes_per_candidate(results_by_party['libdem'][:votes], results_by_party['libdem'][:candidates]),
            results_by_party['libdem'][:candidates_elected],
            results_by_party['green'][:votes],
            results_by_party['green'][:candidates],
            votes_per_candidate(results_by_party['green'][:votes], results_by_party['green'][:candidates]),
            results_by_party['green'][:candidates_elected],
            results_by_party['other'][:votes],
            results_by_party['other'][:candidates],
            votes_per_candidate(results_by_party['other'][:votes], results_by_party['other'][:candidates]),
            results_by_party['other'][:candidates_elected],
          ]
        end
      end
    end
  end
end
