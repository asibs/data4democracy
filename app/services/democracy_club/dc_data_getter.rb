module DemocracyClub
  # Top-level DemocracyClub class to insert elections data into the app.
  #
  # Requires an election_type_slug (eg. 'parl', 'local'), which determines the
  # type of elections this class will load.
  #
  # Optionally accepts update_mode. If set to true, the class will check
  # all elections are up-to-date with the latest data from DC, otherwise it
  # will only insert data about new elections which aren't yet in our database.
  # Defaults to false.
  class DcDataGetter < ApplicationService
    def initialize(election_type_slug:, update_mode: false)
      @dc_api = DemocracyClub::DcApi.new

      @election_type_slug = election_type_slug
      @update_mode = update_mode
    end

    def call
      @dc_api.elections(election_type: @election_type_slug).each do |page|
        page.each do |election_json|
          create_election(election_json)
        end
      end
    end

    private

    def create_election(election_json)
      election = Election.find_or_initialize_by(slug: election_json['slug'])

      return false unless @update_mode || election.new_record?

      election_type = ElectionType.find_by!(slug: election_json['slug'].split('.')&.first)
      election.election_type = election_type
      election.election_date = Date.parse(election_json['election_date'])
      election.save!

      election_json['ballots'].map { |b| b['ballot_paper_id'] }.each do |ballot_paper_id|
        ballot_json = @dc_api.ballot(ballot_paper_id: ballot_paper_id)
        result_json = @dc_api.result(ballot_paper_id: ballot_paper_id)

        ballot = Ballot.find_or_initialize_by(democracy_club_id: ballot_json['ballot_paper_id'])
        ballot.election = election
        ballot.area = find_or_create_area_from_ballot!(ballot_json)
      end
    end

    def find_or_create_area_from_ballot!(ballot_json)
      ballot_id = ballot_json['ballot_paper_id']
      post_id = ballot_json.dig('post', 'id')

      raise "No Post ID found for ballot #{ballot_id}" unless post_id.present?

      raise "Post ID is not a GSS code for ballot #{ballot_id}" unless post_id.starts_with?('gss:')

      gss_code = post_id.remove(/^gss:/)

      Area.find_by(gss_code: gss_code) || Mapit::MapitAreaCreator.call(gss_code: gss_code)
    end
  end
end
