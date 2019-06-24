#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/page"
require "cwm/pager"

class TestPage < CWM::Page
  attr_reader :label, :contents
  def initialize(number)
    self.widget_id = "page#{number}"
    @label = "Page #{number}"
    @contents = Yast::Term.new(:Empty, Yast::Term.new(:id, "empty#{number}"))
  end
end

describe CWM::Page do
  subject do
    TestPage.new(0)
  end

  include_examples "CWM::CustomWidget"
end

describe CWM::Pager do
  class MyPager < CWM::Pager
    def initialize
      @pages = [TestPage.new(1), TestPage.new(2)]
      super(*@pages)
      init
    end

    def contents
      VBox(*@pages)
    end

    def mark_page(_page); end
  end
  subject do
    MyPager.new
  end

  include_examples "CWM::Pager"
end
