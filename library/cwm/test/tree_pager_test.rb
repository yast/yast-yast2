#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/tree_pager"
require "yast"
Yast.import "UI"

describe CWM::TreePager do
  class TestPage < CWM::Page
    attr_reader :label, :contents
    def initialize(number)
      self.widget_id = "page#{number}"
      @label = "Page #{number}"
      @contents = Yast::Term.new(:Empty, Yast::Term.new(:id, "empty#{number}"))
    end
  end

  class PagerTestTree < CWM::Tree
    def label
      "my tree pager"
    end

    def items
      page = TestPage.new(42)
      [
        CWM::PagerTreeItem.new(page)
      ]
    end
  end

  subject do
    pager = CWM::TreePager.new(PagerTestTree.new)
    pager.init
    pager
  end

  include_examples "CWM::Pager"
end
