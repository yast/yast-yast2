# typed: strict

module Yast
  module SCR
    sig do
      params(
        scr_path: T.any(::String, Yast::Path),
        arg1: T.untyped,
        arg2: T.untyped
      ).returns(T.untyped)
    end
    def self.Execute(scr_path, arg1 = T.unsafe(nil), arg2 = T.unsafe(nil)); end
  end
end
