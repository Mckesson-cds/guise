require 'factory_girl'

require File.expand_path('../support/database.rb', __FILE__)

RSpec.configure do |config|

  config.before :suite do
    Database.create
    FactoryGirl.find_definitions
  end

  config.include FactoryGirl::Syntax::Methods
end
