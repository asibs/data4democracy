module Mapit
  class MapitApi
    BASE_URI = 'https://mapit.mysociety.org/'

    AREA_URI = URI::join(BASE_URI, 'area/')
    GENERATIONS_URI = URI::join(BASE_URI, 'generations')

    def initialize
      @connection = Faraday.new do |f|
        f.use FaradayMiddleware::FollowRedirects, limit: 5
        f.adapter Faraday.default_adapter
      end
    end

    # Get a single area
    def area(gss_code:)
      uri = URI::join(AREA_URI, gss_code)
      get_data(uri)
    end

    # Get the geography for a single area
    def area_geography(gss_code:)
      uri = URI::join(AREA_URI, "#{gss_code}.geojson")
      get_data(uri)
    end

    # Get all generations
    def generations
      # Cache generations rather than spamming Mapit API - they change VERY rarely
      @generations = get_data(GENERATIONS_URI)
    end

    def generation(generation_id:)
      generations[generation_id]
    end

    private

    def get_data(uri, params = {})
      response = @connection.get(uri, params)

      raise MapitApiError, "HTTP code #{response.status}" unless response.success?

      response.body
    end

  class MapitApiError < StandardError; end
end
