module DemocracyClub
  class DcApi
    BASE_URI = 'https://candidates.democracyclub.org.uk/api/next/'

    BALLOTS_URI = URI::join(BASE_URI, 'ballots/')
    ELECTIONS_URI = URI::join(BASE_URI, 'elections/')
    PARTIES_URI = URI::join(BASE_URI, 'parties/')
    PEOPLE_URI = URI::join(BASE_URI, 'people/')
    RESULTS_URI = URI::join(BASE_URI, 'results/')

    def initialize
      retry_options = {
        max: 5,
        interval: 5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [429] # Retry rate-limits after the correct amount of time
      }

      @connection = Faraday.new do |faraday|
        faraday.request :retry, retry_options
        faraday.response :follow_redirects # use Faraday::FollowRedirects::Middleware
        faraday.adapter Faraday.default_adapter
      end
    end

    # Get all ballots that match the given filters
    # (or just all ballots if no params passed)
    def ballots(election_type: nil, election_date_after: nil, election_date_before: nil, has_results: nil)
      get_paged_data(
        BALLOTS_URI,
        {
          election_type: election_type,
          election_date_range_after: election_date_after&.strftime('%F'),
          election_date_range_before: election_date_before&.strftime('%F'),
          has_results: has_results
        }
      )
    end

    # Get a single ballot
    def ballot(ballot_paper_id:)
      uri = URI::join(BALLOTS_URI, ERB::Util.url_encode(ballot_paper_id))
      get_json_data(uri)
    end

    # Get all elections
    def elections
      get_paged_data(ELECTIONS_URI)
    end

    # Get a single election
    def election(election_slug:)
      uri = URI::join(ELECTIONS_URI, ERB::Util.url_encode(election_slug))
      get_json_data(uri)
    end

    # Get all parties
    def parties
      get_paged_data(PARTIES_URI)
    end

    # Get a single party
    def party(party_ec_id:)
      uri = URI::join(PARTIES_URI, ERB::Util.url_encode(party_ec_id))
      get_json_data(uri)
    end

    # Get all people
    def people
      get_paged_data(PEOPLE_URI)
    end

    # Get a single person
    def person(person_id:)
      uri = URI::join(PEOPLE_URI, ERB::Util.url_encode(person_id))
      get_json_data(uri)
    end

    # Get all results
    def results
      get_paged_data(RESULTS_URI)
    end

    # Get results of a single ballot
    def result(ballot_paper_id:)
      uri = URI::join(RESULTS_URI, ERB::Util.url_encode(ballot_paper_id))
      get_json_data(uri)
    end

    private

    def get_data(uri, params = {})
      response = @connection.get(uri, params)

      raise DcApiError.new(response.status) unless response.success?

      response.body
    end

    def get_json_data(uri, params = {})
      JSON.parse(get_data(uri, params))
    end

    def get_paged_data(uri, params = {})
      PagedApiData.new(self, get_json_data(uri, params))
    end

    # Convenience wrapper class for paged data from DC, providing an easy way to get next & previous pages.
    #
    # Also implements Enumerable, so you can write code like:
    #
    # DcApi.new.elections(election_type: 'parl').each do |page|
    #   page.each do |election|
    #     puts "Election #{election['name']} happened on #{election['election_date']}"
    #   end
    # end
    class PagedApiData
      include Enumerable

      def initialize(dc_api, json_data)
        @dc_api = dc_api
        @json_data = json_data
      end

      def result_count
        @json_data['count']
      end

      def results
        @json_data['results']
      end

      def next_page
        return nil unless @json_data['next'].present?

        @dc_api.send(:get_paged_data, @json_data['next'])
      end

      def previous_page
        return nil unless @json_data['previous'].present?

        @dc_api.send(:get_paged_data, @json_data['previous'])
      end

      def each(&block)
        block.call(results)
        next_page&.each(&block)
      end
    end
  end

  class DcApiError < StandardError
    attr_reader :http_code

    def initialize(http_code)
      @http_code = http_code
      super("HTTP code #{http_code}")
    end
  end
end
