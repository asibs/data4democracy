module Mapit
  class MapitApi
    BASE_URI = 'https://mapit.mysociety.org/'

    AREA_URI = URI::join(BASE_URI, 'area/')
    GENERATIONS_URI = URI::join(BASE_URI, 'generations')

    def initialize
      retry_options = {
        max: 3,
        interval: 0.5,
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

    # Get a single area
    def area(gss_code:)
      uri = URI::join(AREA_URI, "#{gss_code}.json")
      get_json_data(uri)
    end

    # Get the boundary data for a single area
    def area_boundary(gss_code:, simplify_tolerance: nil)
      uri = URI::join(AREA_URI, "#{gss_code}.wkt")
      params = {}
      params['simplify_tolerance'] = simplify_tolerance if simplify_tolerance.present?
      get_data(uri, params)
    end

    # Get all generations
    def generations
      # Cache generations rather than spamming Mapit API - they change VERY rarely
      @generations = get_json_data(GENERATIONS_URI)
    end

    def generation(generation_id:)
      generations.values.select { |g| g['id'] == generation_id }.first
    end

    private

    def get_data(uri, params = {})
      response = @connection.get(uri, params)

      raise MapitApiError, "HTTP code #{response.status}" unless response.success?

      response.body
    end

    def get_json_data(uri, params = {})
      JSON.parse(get_data(uri, params))
    end

    class MapitApiError < StandardError; end
  end
end
