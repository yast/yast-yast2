require "yast"
require "yast2/target_file"

require "cfa/base_model"
require "cfa/matcher"
require "cfa/augeas_parser"

module CFA
  # class representing /etc/aliases configuration file
  class Aliases < BaseModel
    PARSER = AugeasParser.new("aliases.lns")
    PATH = "/etc/aliases".freeze
    include Yast::Logger

    def initialize(file_handler: nil)
      super(PARSER, PATH, file_handler: file_handler)
    end

    # return hash with alias as key and destination as value. If more destination is there, it use comma separated format.
    def aliases
      matcher = Matcher.new { |k, _v| k =~ /^\d*$/ }
      data.select(matcher).each_with_object({}) do |tree, result|
        tree = tree[:value]
        result[tree["name"]] = string_value(tree)
      end
    end

    def aliases=(list)
      previous = aliases
      to_remove = previous.keys - list.keys
      delete_matcher = Matcher.new { |k, v| k =~ /^\d*$/ && to_remove.include?(v["name"])}
      data.delete(delete_matcher)

      matcher = Matcher.new { |k, _v| k =~ /^\d*$/ }
      data.select(matcher).each do |tree|
        tree = tree[:value]
        next if string_value(tree) == list[tree["name"]]

        assign_value(tree, list[tree["name"]])
      end

      highest_number = data.select(matcher).map{|d| d[:key].to_i}.max
      to_add = list.keys - previous.keys
      to_add.each do |key|
        highest_number += 1
        new_tree = AugeasTree.new
        new_tree["name"] = key
        assign_value(new_tree, list[key])
        data[highest_number.to_s] = new_tree
      end
    end

  private

    def string_value(tree)
      if tree["value"]
        tree["value"]
      else
        tree.collection("value").map(&:to_s).join(", ")
      end
    end

    def assign_value(tree, string_value)
      tree.delete("value")
      tree.delete("value[]")
      values = string_value.split(",").map(&:strip)
      if values.size == 1
        tree["value"] = values.first
      else
        collection = tree.collection("value")
        values.each { |v| collection.add(v) }
      end
    end
  end
end
