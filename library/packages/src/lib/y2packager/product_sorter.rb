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

module Y2Packager
  # Sorter for sorting Products in required display order
  # @param x [Y2Packager::Product] the first item to compare
  # @param y [Y2Packager::Product] the second item to compare
  PRODUCT_SORTER = proc do |x, y|
    # both products have defined order
    if x.order && y.order
      x.order <=> y.order
    # only one product has defined order
    elsif x.order || y.order
      # product with defined order first
      x.order ? -1 : 1
    else
      # none product has defined order, sort by label
      x.label <=> y.label
    end
  end
end
