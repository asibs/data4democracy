# Data 4 Democracy

## About

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

**Run the app**

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
