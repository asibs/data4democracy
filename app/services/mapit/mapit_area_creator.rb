module Mapit
  class MapitAreaCreator < ApplicationService
    def initialize(gss_code:)
      @mapit_api = Mapit::MapitApi.new

      @gss_code = gss_code
    end

    def call
      area_json = @mapit_api.area(gss_code: @gss_code)

      area = Area.find_or_initialize_by(gss_code: @gss_code)
      area.name = area_json['name']
      area.area_type = find_or_create_area_type!(area_json['type'], area_json['type_name'])
      area.valid_from = get_valid_from(area_json['generation_low'])
      area.valid_until = get_valid_until(area_json['generation_high'])
      area.active = get_active(area_json['generation_high'])
      area.save!

      area_geography = @mapit_api.area_geography(gss_code: @gss_code)
      # TODO: Insert area_geography record
    end

    private

    def find_or_create_area_type!(slug, name)
      area_type = AreaType.find_or_initialize_by(slug: slug)
      area_type.name = name
      area_type.save!
    end

    def get_valid_from(generation_id)
      generation_json = @mapit_api.generation(generation_id: generation_id)
      Date.parse(generation_json['created'])
    end

    def get_valid_until(generation_id)
      generation_json = @mapit_api.generation(generation_id: generation_id)

      return nil if generation_json['active']

      # TODO: unclear if this is correct, or even if there is a way to tell the date it became invalid...
      # Generations don't have an 'end date', just created date & whether they are currently active...
      # May just need to take the date we found out the area is no longer active...?
      # Speak to MapIt team once we have an API key
      Date.parse(generation_json['created'])
    end

    def get_active(generation_id)
      generation_json = @mapit_api.generation(generation_id: generation_id)
      generation_json['active']
    end
  end
end
