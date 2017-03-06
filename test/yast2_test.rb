require_relative "test_helper"

require "cheetah"

additional_y2dir = File.expand_path("../test_y2dir", __FILE__)
ENV["Y2DIR"] += ":#{additional_y2dir}"
TEST_DIR = File.expand_path("../../scripts", __FILE__)

describe "yast2 script" do
  it "pass properly all arguments" do
    Cheetah.run(TEST_DIR + "/yast2", "args_test_client", 'abc"\'\\|;&<>! ', "second", env: { "TESTING_YAST2" => "1" })
  end
end
