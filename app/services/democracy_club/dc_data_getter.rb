module DemocracyClub
  # Top-level DemocracyClub class to insert elections data into the app.
  #
  # Requires an election_type_slug (eg. 'parl', 'local'), which determines the
  # type of elections this class will load.
  #
  # Optionally accepts an election_date_after, eg. 1.year.ago
  #
  # Optionally accepts update_mode. If set to true, the class will check
  # all elections are up-to-date with the latest data from DC, otherwise it
  # will only insert data about new elections which aren't yet in our database.
  # Defaults to false.
  #
  # Example usage:
  #   DemocracyClub::DcDataGetter.call(election_type_slug: 'parl', update_mode: true)
  class DcDataGetter < ApplicationService
    def initialize(election_type_slug:, election_date_after: nil, election_date_before: nil, update_mode: false)
      @dc_api = DemocracyClub::DcApi.new

      @election_type_slug = election_type_slug
      @election_date_after = election_date_after
      @election_date_before = election_date_before
      @update_mode = update_mode
    end

    def call
      @dc_api.ballots(
        election_type: @election_type_slug,
        election_date_after: @election_date_after,
        election_date_before: @election_date_before,
        has_results: true
      ).each do |page|
        page.each do |ballot_json|
          begin
            create_ballot(ballot_json)
          rescue UnexpectedPostId => e
            Rails.logger.error { e.message }
          end
        end
      end
    end

    private

    def create_ballot(ballot_json)
      ballot_paper_id = ballot_json['ballot_paper_id']
      ballot = Ballot.find_or_initialize_by(democracy_club_id: ballot_paper_id)

      return false unless ballot.new_record? || @update_mode

      result_json = @dc_api.result(ballot_paper_id: ballot_paper_id)

      election = find_or_create_election!(ballot_json['election'])

      ballot.election = election
      ballot.area = find_or_create_area_from_ballot!(ballot_json)
      ballot.total_electorate = result_json['total_electorate']
      ballot.turnout_number = result_json['num_turnout_reported']
      ballot.turnout_percentage = result_json['turnout_percentage']
      ballot.number_of_spoilt_ballots = result_json['num_spoilt_ballots']
      ballot.save!

      result_json['candidate_results'].each do |candidate_result_json|
        candidate = Candidate.find_or_initialize_by(
          ballot: ballot,
          person: find_or_create_person!(candidate_result_json.dig('person', 'id')),
          party: find_or_create_party!(candidate_result_json.dig('party', 'ec_id'))
        )
        candidate.elected = (candidate_result_json['elected'] == true) # Required because DC API is NULL for some candidates
        candidate.number_of_ballots = candidate_result_json['num_ballots']
        candidate.save!
      end
    end

    def find_or_create_election!(election_json)
      election_type = ElectionType.find_by!(slug: election_json['election_id'].split('.')&.first)

      Election.find_or_create_by!(
        slug: election_json['election_id'],
        election_type: election_type,
        election_date: Date.parse(election_json['election_date'])
      )
    end

    # def create_election(election_json)
    #   election = Election.find_or_initialize_by(slug: election_json['slug'])
    #
    #   return false unless @update_mode || election.new_record?
    #
    #   election_type = ElectionType.find_by!(slug: election_json['slug'].split('.')&.first)
    #   election.election_type = election_type
    #   election.election_date = Date.parse(election_json['election_date'])
    #   election.save!
    #
    #   election_json['ballots'].map { |b| b['ballot_paper_id'] }.each do |ballot_paper_id|
    #     ballot_json = @dc_api.ballot(ballot_paper_id: ballot_paper_id)
    #     result_json = @dc_api.result(ballot_paper_id: ballot_paper_id)
    #
    #     ballot = Ballot.find_or_initialize_by(democracy_club_id: ballot_json['ballot_paper_id'])
    #     ballot.election = election
    #     ballot.area = find_or_create_area_from_ballot!(ballot_json)
    #     ballot.total_electorate = result_json['total_electorate']
    #     ballot.turnout_number = result_json['num_turnout_reported']
    #     ballot.turnout_percentage = result_json['turnout_percentage']
    #     ballot.number_of_spoilt_ballots = result_json['num_spoilt_ballots']
    #
    #     result_json['candidate_results'].each do |candidate_result_json|
    #       candidate = Candidate.find_or_initialize_by(
    #         ballot: ballot,
    #         person: find_or_create_person!(candidate_result_json.dig('person', 'id')),
    #         party: find_or_create_party!(candidate_result_json.dig('party', 'ec_id'))
    #       )
    #       candidate.elected = (candidate_result_json['elected'] == true) # Required because DC API is NULL for some candidates
    #       candidate.number_of_ballots = candidate_result_json['num_ballots']
    #       candidate.save!
    #     end
    #   end
    # end

    def find_or_create_area_from_ballot!(ballot_json)
      ballot_id = ballot_json['ballot_paper_id']
      post_id = ballot_json.dig('post', 'id')

      raise UnexpectedPostId, "No Post ID found for ballot #{ballot_id}" unless post_id.present?

      raise UnexpectedPostId, "Post ID #{post_id} is not a GSS code - for ballot #{ballot_id}" unless post_id.starts_with?('gss:')

      gss_code = post_id.remove(/^gss:/)

      Area.find_by(gss_code: gss_code) || FindThatPostcode::FindThatPostcodeAreaCreator.call(gss_code: gss_code)
    end

    def find_or_create_person!(person_id)
      person_json = @dc_api.person(person_id: person_id)

      person = Person.find_or_initialize_by(democracy_club_id: person_id)
      person.name = person_json['name']
      person.honorific_prefix = person_json['honorific_prefix']
      person.honorific_suffix = person_json['honorific_suffix']
      # Birth/death date seem to always be just a year, not a full date...
      # person.birth_date = Date.parse(person_json['birth_date']) if person_json['birth_date'].present?
      # person.death_date = Date.parse(person_json['death_date']) if person_json['death_date'].present?
      person.gender = person_json['gender']
      person.save!

      person
    end

    def find_or_create_party!(party_id)
      party = Party.find_or_initialize_by(ec_id: party_id)

      return party unless party.new_record?

      party_json = @dc_api.party(party_ec_id: party_id)
      party.name = party_json['name']
      party.save!

      party
    end
  end

  class UnexpectedPostId < StandardError; end
end
