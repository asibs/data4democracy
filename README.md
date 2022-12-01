# Data 4 Democracy

## About

Data4Democracy provides local data about UK constituencies and electoral wards.
This includes election results and demographic data.

This project is still in the early phases, but the intention is that Data4Democracy
will provide an API to get data, as well as a UI to browse data.

## Installation

### Local Install

**Pre-requisites**

- Install Ruby (currently 3.1.2) - [Ruby Version Manager](https://rvm.io/) is recommended
- Install [Bundler](https://bundler.io/) (`gem install bundler`)
- Install postgres with the postGIS extension:
  - `sudo apt-get install postgresql-12 postgresql-client-12`
  - `sudo apt-get install postgis postgresql-12-postgis-3`
- Create a superuser postgres account for yourself:
  - `sudo su - postgres`
  - `psql`
  - `CREATE USER <YOUR TERMINAL USERNAME> WITH CREATEDB CREATEUSER;`

**Install the Rails application**

- Clone the repo (`git clone git@github.com:asibs/data4democracy.git`)
- Switch into the app directory (`cd data4democracy`)
- Install the dependencies (`bundle install`)
- Setup the database & schema (`rails db:create & rails db:migrate`)
- Add initial seed data (`rails db:seed`)

**Get data**

The election data is loaded from [Democracy Club](https://democracyclub.org.uk/) and area /
boundary data is loaded from [FindThatPostcode](https://findthatpostcode.uk/).

Run the rails console: `rails c`

```ruby
# Load Westminster Parliamentary elections
DemocracyClub::DcDataGetter.call(election_type_slug: 'parl')

# Load Local Council elections
DemocracyClub::DcDataGetter.call(election_type_slug: 'local')
```

This will take _a long time_ if you run it for all elections, as it will load election
results _and_ area boundary geographic data.

You can limit it to certain dates by also passing the `election_date_before` & `election_date_after`
parameters.

**Run the app**

Run the server: `rails s`

You can then access a proof-of-concept UI from: http://localhost:3000/areas/

Click on an area from the list to see a map with that constituency highlighted in red.

### Heroku Install

TODO










This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...


#
