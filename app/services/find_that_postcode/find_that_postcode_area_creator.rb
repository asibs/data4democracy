module FindThatPostcode
  class FindThatPostcodeAreaCreator < ApplicationService
    def initialize(gss_code:)
      @api = FindThatPostcode::FindThatPostcodeApi.new

      @gss_code = gss_code
    end

    def call
      area_json = @api.area(gss_code: @gss_code)

      area = Area.find_or_initialize_by(gss_code: @gss_code)
      area.name = area_json['data']['attributes']['name']
      area.area_type = find_or_create_area_type!(area_json)
      area.valid_from = get_valid_from(area_json)
      area.valid_until = get_valid_until(area_json)
      area.active = get_active(area_json)
      area.save!

      find_or_create_area_boundary(area)

      area
    end

    private

    def find_or_create_area_type!(area_json)
      area_type_slug = area_json['data']['relationships']['areatype']['data']['id']

      area_type = AreaType.find_or_initialize_by(slug: area_type_slug)

      if area_type.new_record?
        area_type_json = @api.area_type(slug: area_type_slug)

        area_type.name = area_type_json['data']['attributes']['full_name']
        area_type.save!
      end

      area_type
    end

    def find_or_create_area_boundary(area)
      area_boundary = AreaBoundary.find_or_initialize_by(area: area)

      if area_boundary.new_record?
        begin
          boundary_geojson = @api.area_boundary(gss_code: area.gss_code)

          boundary = convert_geojson(boundary_geojson)

          area_boundary.boundary = boundary
          area_boundary.save!
        rescue FindThatPostcode::FindThatPostcodeApiError => e
          if e.http_code == 404
            Rails.logger.error { "FindThatPostcode returned 404 for boundary for area #{area.gss_code}" }
          else
            raise
          end
        end
      end
    end

    def get_valid_from(area_json)
      date_start = area_json['data']['attributes']['date_start']
      Date.parse(date_start)
    end

    def get_valid_until(area_json)
      date_end = area_json['data']['attributes']['date_end']

      return nil if date_end.blank?

      Date.parse(date_end)
    end

    def get_active(area_json)
      date_end = area_json['data']['attributes']['date_end']

      date_end.blank?
    end

    # def convert_geojson(boundary_geojson)
    #   geometry = RGeo::GeoJSON.decode(boundary_geojson)
    #
    #   case geometry
    #   when  RGeo::GeoJSON::Feature
    #     [geometry.geometry]
    #   when  RGeo::GeoJSON::FeatureCollection
    #     geometry.map(&:geometry)
    #   when nil # case happening when given an incomplete geojson
    #     []
    #   else
    #     [geometry]
    #   end
    # end

    def convert_geojson(boundary_geojson)
      geometry = RGeo::GeoJSON.decode(boundary_geojson)

      return geometry unless geometry.is_a? RGeo::GeoJSON::FeatureCollection

      # factory = RGeo::Geographic.spherical_factory(srid: 4326)
      factory = RGeo::Geographic.simple_mercator_factory
      factory.collection(geometry.instance_variable_get('@features').map(&:geometry))
    end
  end
end
