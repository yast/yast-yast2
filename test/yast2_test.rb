#! rspec --format doc

require_relative "test_helper"

require "cheetah"

TEST_DIR = File.expand_path("../scripts", __dir__)

describe "yast2 script" do
  around do |example|
    old_y2dir = ENV.fetch("Y2DIR", nil)
    additional_y2dir = File.expand_path("test_y2dir", __dir__)
    ENV["Y2DIR"] = ENV.fetch("Y2DIR", nil) + ":#{additional_y2dir}"
    example.run
    ENV["Y2DIR"] = old_y2dir
  end

  it "passes properly all arguments" do
    Cheetah.run(TEST_DIR + "/yast2", "args_test_client", 'abc"\'\\|;&<>! ', "second", env: { "TESTING_YAST2" => "1" })
  end
end
