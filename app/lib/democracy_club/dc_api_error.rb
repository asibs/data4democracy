module DemocracyClub
  class DcApiError < StandardError
    attr_reader :http_code

    def initialize(http_code)
      @http_code = http_code
      super("HTTP code #{http_code}")
    end
  end
end
