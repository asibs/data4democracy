# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2022_10_02_151301) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "area_boundaries", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.geometry "boundary", limit: {:srid=>0, :type=>"geometry"}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id"], name: "index_area_boundaries_on_area_id", unique: true
    t.index ["boundary"], name: "index_area_boundaries_on_boundary", using: :gist
  end

  create_table "area_types", force: :cascade do |t|
    t.string "slug", null: false, comment: "A unique slug for an area type - we use the MapIt slug"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_area_types_on_name", unique: true
    t.index ["slug"], name: "index_area_types_on_slug", unique: true
  end

  create_table "areas", force: :cascade do |t|
    t.string "gss_code", null: false, comment: "The unique GSS (Government Statistical Service) code for the area, assigned by the ONS"
    t.string "name", null: false
    t.bigint "area_type_id", null: false
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_areas_on_active"
    t.index ["area_type_id"], name: "index_areas_on_area_type_id"
    t.index ["gss_code"], name: "index_areas_on_gss_code", unique: true
    t.index ["name"], name: "index_areas_on_name"
  end

  create_table "ballots", force: :cascade do |t|
    t.string "democracy_club_id", null: false, comment: "The unique Democracy Club ID for the ballot paper"
    t.bigint "election_id", null: false
    t.bigint "area_id", null: false
    t.integer "total_electorate"
    t.integer "turnout_number"
    t.float "turnout_percentage"
    t.integer "number_of_spoilt_ballots"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id"], name: "index_ballots_on_area_id"
    t.index ["democracy_club_id"], name: "index_ballots_on_democracy_club_id", unique: true
    t.index ["election_id"], name: "index_ballots_on_election_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.bigint "ballot_id", null: false
    t.bigint "person_id", null: false
    t.bigint "party_id"
    t.boolean "elected", null: false
    t.integer "number_of_ballots", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ballot_id"], name: "index_candidates_on_ballot_id"
    t.index ["elected"], name: "index_candidates_on_elected"
    t.index ["number_of_ballots"], name: "index_candidates_on_number_of_ballots"
    t.index ["party_id"], name: "index_candidates_on_party_id"
    t.index ["person_id"], name: "index_candidates_on_person_id"
  end

  create_table "election_types", force: :cascade do |t|
    t.string "slug", null: false, comment: "A unique slug for an election type - we use the Democracy Club slug"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_election_types_on_name", unique: true
    t.index ["slug"], name: "index_election_types_on_slug", unique: true
  end

  create_table "elections", force: :cascade do |t|
    t.string "slug", null: false, comment: "A unique slug for an election - we use the Democracy Club slug"
    t.date "election_date", null: false
    t.bigint "election_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["election_date"], name: "index_elections_on_election_date"
    t.index ["election_type_id"], name: "index_elections_on_election_type_id"
    t.index ["slug"], name: "index_elections_on_slug", unique: true
  end

  create_table "parties", force: :cascade do |t|
    t.string "ec_id", null: false, comment: "The unique Electoral Commission ID for the party"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ec_id"], name: "index_parties_on_ec_id", unique: true
    t.index ["name"], name: "index_parties_on_name"
  end

  create_table "people", force: :cascade do |t|
    t.integer "democracy_club_id", null: false, comment: "The unique Democracy Club ID for the person"
    t.string "name", null: false
    t.string "honorific_prefix"
    t.string "honorific_suffix"
    t.date "birth_date"
    t.date "death_date"
    t.string "gender"
    t.index ["democracy_club_id"], name: "index_people_on_democracy_club_id", unique: true
  end

end
