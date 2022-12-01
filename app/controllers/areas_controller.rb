class AreasController < ApplicationController
  before_action :set_area, only: %i[show boundary]

  # GET /areas
  def index
    @areas = Area.joins(:area_type).where(area_type: { slug: 'pcon' })
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

  private

  def set_area
    @area = Area.find(params[:id])
  end
end
