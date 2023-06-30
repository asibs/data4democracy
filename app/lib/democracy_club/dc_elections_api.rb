module DemocracyClub
  # The main DC API is DemocracyClub::DcApi
  #
  # That API uses what seems to be the preferred / active DC endpoints, on their 'candidates' subdomain.
  #
  # However, some data about elections is not available with that API - specifically, for council elections,
  # we want to know how many seats are in the ward in total, as well as how many seats are up for election.
  # This data does not appear to be available on the 'candidates' API:
  # - https://elections.democracyclub.org.uk/api/elections/local.arun.yapton.2023-05-04/
  #   includes a 'seats_contested' as well as a 'seats_total' field.
  # - https://candidates.democracyclub.org.uk/api/next/ballots/local.arun.yapton.2023-05-04/
  #   only includes 'winner_count', with no way to know the total seats for the ward
  class DcElectionsApi
    BASE_URI = 'https://elections.democracyclub.org.uk/api/'

    ELECTIONS_URI = URI::join(BASE_URI, 'elections/')

    def initialize
      retry_options = {
        max: 5,
        interval: 5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [
          429, # Retry rate-limits after the correct amount of time
          502  # Retry bad gateway
        ]
      }

      @connection = Faraday.new do |faraday|
        faraday.request :retry, retry_options
        faraday.response :follow_redirects # use Faraday::FollowRedirects::Middleware
        faraday.adapter Faraday.default_adapter
      end
    end

    # Get all elections that match the given filters
    # (or just all ballots if no params passed)
    def elections(election_date: nil, election_id_regex: nil)
      get_paged_data(
        ELECTIONS_URI,
        {
          poll_open_date: election_date,
          election_id_regex: election_id_regex
        }
      )
    end

    # Get a single election
    def election(election_id:)
      uri = URI::join(ELECTIONS_URI, ERB::Util.url_encode(election_id))
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
end
