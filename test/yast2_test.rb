#! rspec --format doc
# typed: ignore

require_relative "test_helper"

require "cheetah"

TEST_DIR = File.expand_path("../../scripts", __FILE__)

describe "yast2 script" do
  around do |example|
    old_y2dir = ENV["Y2DIR"]
    additional_y2dir = File.expand_path("../test_y2dir", __FILE__)
    ENV["Y2DIR"] = ENV["Y2DIR"] + ":#{additional_y2dir}"
    example.run
    ENV["Y2DIR"] = old_y2dir
  end

  it "passes properly all arguments" do
    Cheetah.run(TEST_DIR + "/yast2", "args_test_client", 'abc"\'\\|;&<>! ', "second", env: { "TESTING_YAST2" => "1" })
  end
end
