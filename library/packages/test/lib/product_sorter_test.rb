# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "../test_helper"

require "y2packager/product"
require "y2packager/product_sorter"

describe Y2Packager::PRODUCT_SORTER do

  # testing products with defined ordering
  let(:p1) do
    Y2Packager::Product.new(name: "p10", display_name: "Product with order 10", order: 10)
  end

  let(:p2) do
    Y2Packager::Product.new(name: "p20", display_name: "Product with order 20", order: 20)
  end

  let(:p3) do
    Y2Packager::Product.new(name: "p30", display_name: "Product with order 30", order: 30)
  end

  # testing products with undefined (nil) ordering
  let(:pnil1) { Y2Packager::Product.new(name: "p1", display_name: "Product 1 without order") }
  let(:pnil2) { Y2Packager::Product.new(name: "p2", display_name: "Product 2 without order") }

  it "keeps an already sorted list unchanged" do
    products = [p1, p2, p3]
    products.sort!(&::Y2Packager::PRODUCT_SORTER)
    expect(products).to eq([p1, p2, p3])
  end

  it "sorts the products by the ordering number" do
    products = [p3, p2, p1]
    products.sort!(&::Y2Packager::PRODUCT_SORTER)
    expect(products).to eq([p1, p2, p3])
  end

  it "sorts by label if ordering is missing" do
    products = [pnil2, pnil1]
    products.sort!(&::Y2Packager::PRODUCT_SORTER)
    expect(products).to eq([pnil1, pnil2])
  end

  it "puts the products with undefined order at the end" do
    products = [pnil2, p3, pnil1, p1]
    products.sort!(&::Y2Packager::PRODUCT_SORTER)
    expect(products).to eq([p1, p3, pnil1, pnil2])
  end
end
