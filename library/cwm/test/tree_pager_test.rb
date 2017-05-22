#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/tree_pager"
require "yast"
Yast.import "UI"

describe CWM::TreePager do
  class TestPage < CWM::Page
    attr_reader :label, :contents
    def initialize(n)
      self.widget_id = "page#{n}"
      @label = "Page #{n}"
      @contents = Yast::Term.new(:Empty, Yast::Term.new(:id, "empty#{n}"))
    end
  end

  subject do
    page = TestPage.new(42)
    item = CWM::PagerTreeItem.new(page)
    pager = CWM::TreePager.new(item, label: "my tree pager")
    pager.init
    pager
  end

  include_examples "CWM::Pager"
end
