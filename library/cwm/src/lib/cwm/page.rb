# typed: true
require "abstract_method"
require "cwm/custom_widget"
require "yast"
Yast.import "CWM"

module CWM
  # A page widget is a group of widgets that are contained within it.
  # Several pages are in turn contained within a {Pager}.
  #
  # {TreePager} is a {Pager}.
  #
  # {Tabs} is a {Pager} and a {Tab} is its {Page}.
  class Page < CustomWidget
    # @return [Boolean] is this the initially selected tab
    attr_accessor :initial

    # @return [String] Label of {Tab} or of {PagerTreeItem}
    abstract_method :label
  end
end
