#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/tree_pager"
require "yast"
Yast.import "UI"

describe CWM::TreePager do
  subject do
    n = 0
    empty = Yast::Term.new(:Empty, Yast::Term.new(:id, "empty#{n}"))
    page = CWM::Page.new(widget_id: "page#{n}", label: "Page #{n}", contents: empty)
    item = CWM::PagerTreeItem.new(page)
    pager = CWM::TreePager.new(item, label: "my tree pager")
    pager.init
    pager
  end

  include_examples "CWM::Pager"
end
