root_location = File.expand_path("../../", __FILE__)
inc_dirs = Dir.glob("#{root_location}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"
require "yast/rspec"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    if mocks.respond_to?(:verify_partial_doubles=)
      mocks.verify_partial_doubles = true
    end
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
  # for coverage we need to load all ruby files
  Dir["#{root_location}/library/*/src/{module,lib}/**/*.rb"].each { |f| require_relative f }
  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end
