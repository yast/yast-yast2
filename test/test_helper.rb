# typed: false
root_location = File.expand_path("..", __dir__)
inc_dirs = Dir.glob("#{root_location}/library/*/src")
# Y2DIRs location needed for testing purpose
ADDITIONAL_Y2DIRS = [
  # Needed to test Y2DIR support in Yast::Directory
  "#{root_location}/library/general/test",
  # Needed to test Yast::CommandLine usage from a dummy client
  "#{root_location}/library/commandline/test"
].freeze
inc_dirs.concat(ADDITIONAL_Y2DIRS)
ENV["Y2DIR"] = inc_dirs.join(":")

ENV["LC_ALL"] = "C.UTF-8"
ENV["LANG"] = "C.UTF-8"

require "yast"
require "yast/rspec"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    mocks.verify_partial_doubles = true if mocks.respond_to?(:verify_partial_doubles=)
  end

  config.extend Yast::I18n  # available in context/describe
  config.include Yast::I18n # available in it/let/before/...
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  top_location = File.expand_path("..", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{top_location}/**/src/**/*.rb")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end
