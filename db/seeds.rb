# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

################################################################################
#####                    DEMOCRACY CLUB ELECTION TYPES                     #####
#####                                                                      #####
##### These can be found at in the API:                                    #####
##### https://candidates.democracyclub.org.uk/api/next/election_types/     #####
#####                                                                      #####
##### However, the slugs currently appear to be broken, as they include a  #####
##### date and/or location in the slug. Eg. We'd expect election type      #####
##### slugs of 'parl' and 'local', but the API shows 'parl.2010-11-05' and #####
##### 'local.north-devon.2019-05-02'                                       #####
#####                                                                      #####
##### If/when this is corrected, we could load these in automatically via  #####
##### the API.                                                             #####
################################################################################
ElectionType.create_or_find_by(slug: 'parl', name: 'UK Parliament elections')
ElectionType.create_or_find_by(slug: 'local', name: 'Local elections')
# Add other election types if & when we want to load such elections into the system
