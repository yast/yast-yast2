# encoding: utf-8

#  ProductProfile.ycp
#  Tests of ProductProfile routines
module Yast
  class ProductProfileClient < Client
    def main
      # testedfiles: ProductProfile.ycp
      Yast.import "Testsuite"
      Yast.import "ProductProfile"

      @READ = { "target" => { "tmpdir" => "/tmp/YaST" } }
      @EX = { "target" => { "bash_output" => {} } }

      # just returns true because of non-installation mode
      Testsuite.Test(->() { ProductProfile.CheckCompliance(nil) },
        [
          @READ,
          {},
          @EX
        ], 0)

      Testsuite.Test(->() { ProductProfile.compliance_checked }, [], 0)

      Yast.import "Mode"
      Mode.SetMode("installation")

      ProductProfile.compliance_checked = { 1 => true }

      # exits on compliance_checked test
      Testsuite.Test(->() { ProductProfile.CheckCompliance(nil) },
        [
          @READ,
          {},
          @EX
        ], 0)

      Testsuite.Test(->() { ProductProfile.CheckCompliance(1) },
        [
          @READ,
          {},
          @EX
        ], 0)

      # this would continue to IsCompliant and initialize Pkg::
      # Testsuite::Test (``(ProductProfile::CheckCompliance (2)), [ READ, $[], EX ], 0);

      nil
    end
  end
end

Yast::ProductProfileClient.new.main
