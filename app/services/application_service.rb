# Based on https://www.honeybadger.io/blog/refactor-ruby-rails-service-object/
class ApplicationService
  def self.call(...)
    new(...).call
  end
end
