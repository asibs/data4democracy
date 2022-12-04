class AreasController < ApplicationController
  before_action :set_area, only: %i[show boundary subareas]

  # GET /areas
  def index
    @areas = Area.joins(:area_type).where(area_type: { slug: 'pcon' }, active: true)
  end

  # GET /areas/:id
  def show
  end

  # GET /areas/:id/boundary
  def boundary
    result = ActiveRecord::Base.connection.execute(
      <<~SQL
        SELECT ST_AsGeoJSON(ab.boundary) FROM area_boundaries ab WHERE ab.area_id = #{@area.id}
      SQL
    )

    geojson_string = result.to_a.dig(0, 'st_asgeojson')
    geojson = JSON.parse(geojson_string)

    render json: geojson, status: :ok
  end

  # GET /areas/:id/subareas
  def subareas
    subarea_type = params[:area_type] || 'ward'

    # TODO: Because the boundaries we've stored don't have 100% accuracy, even using
    # ST_Overlaps || ST_Covers we still get areas which just touch the area boundary
    # (ST_Overlaps || ST_Covers shouldn't return other areas where boundaries just
    # TOUCH - whereas ST_Intersects DOES return areas which touch...)
    #
    # Might be better off just using MapIt APIs here. We could query:
    # https://mapit.mysociety.org/area/66053/covers?type=...
    # https://mapit.mysociety.org/area/66053/overlaps?type=...
    # and show different colors for wards which are 100% contained within the constituency
    # (probably most useful) vs those which are only partially contained.
    #
    # Note, that MapIt uses multiple different area types for wards depending on what
    # type of ward they are (Unitary Authority Ward, London Ward, etc...)
    @subareas = Area.joins(:area_type, :area_boundary).where(area_type: { slug: subarea_type }, active: true).where(
      'ST_Overlaps(area_boundaries.boundary, (SELECT boundary FROM area_boundaries WHERE area_id = ?))', @area.id
    )
  end

  private

  def set_area
    @area = Area.find(params[:id])
  end
end
