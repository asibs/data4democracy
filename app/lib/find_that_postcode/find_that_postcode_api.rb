module FindThatPostcode
  class FindThatPostcodeApi
    BASE_URI = 'https://findthatpostcode.uk/'

    AREA_URI = URI::join(BASE_URI, 'areas/')
    AREA_TYPE_URI = URI::join(BASE_URI, 'areatypes/')

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

    # Get a single area
    def area(gss_code:)
      uri = URI::join(AREA_URI, "#{gss_code}.json")
      get_json_data(uri)
    end

    # Get the boundary data for a single area
    def area_boundary(gss_code:)
      uri = URI::join(AREA_URI, "#{gss_code}.geojson")
      get_json_data(uri)
    end

    # Get a single area type
    def area_type(slug:)
      uri = URI::join(AREA_TYPE_URI, "#{slug}.json")
      get_json_data(uri)
    end

    private

    def get_data(uri, params = {})
      response = @connection.get(uri, params)

      raise FindThatPostcodeApiError.new(response.status) unless response.success?

      response.body
    end

    def get_json_data(uri, params = {})
      JSON.parse(get_data(uri, params))
    end
  end

  class FindThatPostcodeApiError < StandardError
    attr_reader :http_code

    def initialize(http_code)
      @http_code = http_code
      super("HTTP code #{http_code}")
    end
  end
end
