# encoding: utf-8

module Yast
  class IsemptyClient < Client
    def main
      Yast.import "Assert"
      Yast.import "TypeRepository"

      Assert.Equal(true, TypeRepository.IsEmpty(nil))
      Assert.Equal(true, TypeRepository.IsEmpty(""))
      Assert.Equal(true, TypeRepository.IsEmpty([]))
      Assert.Equal(true, TypeRepository.IsEmpty({}))
      Assert.Equal(true, TypeRepository.IsEmpty(HBox()))

      Assert.Equal(false, TypeRepository.IsEmpty(0))
      Assert.Equal(false, TypeRepository.IsEmpty(0.0))
      Assert.Equal(false, TypeRepository.IsEmpty("item"))
      Assert.Equal(false, TypeRepository.IsEmpty(["item"]))
      Assert.Equal(false, TypeRepository.IsEmpty({ "dummy" => "item" }))
      Assert.Equal(false, TypeRepository.IsEmpty(HBox(Label())))
      Assert.Equal(false, TypeRepository.IsEmpty(false))
      Assert.Equal(false, TypeRepository.IsEmpty(true))

      nil
    end
  end
end

Yast::IsemptyClient.new.main
