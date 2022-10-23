class CreateInitialSchema < ActiveRecord::Migration[7.0]
  def change
    create_table :area_types do |t|
      t.string :slug, null: false, index: { unique: true }, comment: 'A unique slug for an area type - we use the MapIt slug'
      t.string :name, null: false, index: { unique: true }

      t.timestamps
    end

    create_table :election_types do |t|
      t.string :slug, null: false, index: { unique: true }, comment: 'A unique slug for an election type - we use the Democracy Club slug'
      t.string :name, null: false, index: { unique: true }

      t.timestamps
    end

    # TODO: Decide if we need organizations...
    # create_table :organization_types do |t|
    #   t.string :slug, null: false, index: { unique: true }, comment: 'A unique slug for an organization type - we use the Democracy Club slug'
    #   t.string :name, null: false, index: true
    #
    #   t.timestamps
    # end

    create_table :areas do |t|
      t.string :gss_code, null: false, index: { unique: true }, comment: 'The unique GSS (Government Statistical Service) code for the area, assigned by the ONS'
      t.string :name, null: false, index: true
      t.references :area_type, null: false, index: true
      t.datetime :valid_from
      t.datetime :valid_until
      t.boolean :active, null: false, index: true, default: true

      t.timestamps
    end

    create_table :area_boundaries do |t|
      t.references :area, null: false, index: { unique: true }
      t.geometry :boundary, null: false, index: { using: :gist }

      t.timestamps
    end

    # TODO: Decide if we need organizations...
    # create_table :organizations do |t|
    #   t.string :slug, null: false, index: { unique: true }, comment: 'A unique slug for the organization - we use the Democracy Club slug'
    #   t.string :name, null: false, index: true
    #   t.references :organization_type, null: false, index: true
    #
    #   t.timestamps
    # end

    create_table :parties do |t|
      t.string :ec_id, null: false, index: { unique: true }, comment: 'The unique Electoral Commission ID for the party'
      t.string :name, null: false, index: true

      t.timestamps
    end

    create_table :people do |t|
      t.integer :democracy_club_id, null: false, index: { unique: true }, comment: 'The unique Democracy Club ID for the person'
      t.string :name, null: false
      t.string :honorific_prefix
      t.string :honorific_suffix
      t.date :birth_date
      t.date :death_date
      t.string :gender
    end

    create_table :elections do |t|
      t.string :slug, null: false, index: { unique: true }, comment: 'A unique slug for an election - we use the Democracy Club slug'
      t.date :election_date, null: false, index: true
      t.references :election_type, null: false, index: true

      t.timestamps
    end

    create_table :ballots do |t|
      t.string :democracy_club_id, null: false, index: { unique: true }, comment: 'The unique Democracy Club ID for the ballot paper'
      t.references :election, null: false
      t.references :area, null: false
      t.integer :total_electorate
      t.integer :turnout_number
      t.float :turnout_percentage
      t.integer :number_of_spoilt_ballots

      t.timestamps
    end

    create_table :candidates do |t|
      t.references :ballot, null: false
      t.references :person, null: false
      t.references :party, null: true
      t.boolean :elected, null: false, index: true
      t.integer :number_of_ballots, null: false, index: true

      t.timestamps
    end
  end
end
