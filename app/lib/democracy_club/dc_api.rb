module DemocracyClub
  class DcApi
    BASE_URI = 'https://candidates.democracyclub.org.uk/api/next/'

    ELECTIONS_URI = URI::join(BASE_URI, 'elections/')
    BALLOTS_URI = URI::join(BASE_URI, 'ballots/')
    RESULTS_URI = URI::join(BASE_URI, 'results/')

    def initialize
      @connection = Faraday.new do |f|
        f.use FaradayMiddleware::FollowRedirects, limit: 5
        f.adapter Faraday.default_adapter
      end
    end

    # Get all elections
    def elections(election_type:)
      get_paged_data(ELECTIONS_URI, { election_type: election_type })
    end

    # Get a single election
    def election(election_slug:)
      uri = URI::join(ELECTIONS_URI, election_slug)
      get_data(uri)
    end

    # Get all ballots
    def ballots
      get_paged_data(BALLOTS_URI)
    end

    # Get a single ballot
    def ballot(ballot_paper_id:)
      uri = URI::join(BALLOTS_URI, ballot_paper_id)
      get_data(uri)
    end

    # Get all results
    def results
      get_paged_data(RESULTS_URI)
    end

    # Get results of a single ballot
    def result(ballot_paper_id:)
      uri = URI::join(RESULTS_URI, ballot_paper_id)
      get_data(uri)
    end

    private

    def get_data(uri, params = {})
      response = @connection.get(uri, params)

      raise DcApiError, "HTTP code #{response.status}" unless response.success?

      response.body
    end

    def get_paged_data(uri, params = {})
      PagedApiData.new(self, get_data(uri, params))
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

      def initialize(dc_api, raw_data)
        @dc_api = dc_api
        @json_data = JSON.parse(raw_data)
      end

      def result_count
        @json_data['count']
      end

      def results
        @json_data['results']
      end

      def next_page
        return nil unless @json_data['next'].present?

        @dc_api.get_paged_data(@json_data['next'])
      end

      def previous_page
        return nil unless @json_data['previous'].present?

        @dc_api.get_paged_data(@json_data['previous'])
      end

      def each(&block)
        block.call(results)
        next_page&.each(block)
      end
    end
  end

  class DcApiError < StandardError; end
end
