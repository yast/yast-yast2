# typed: strict

module Yast
  module Logger
    sig { returns(::Logger) }
    def log; end

    module ClassMethods
      sig { returns(::Logger) }
      def log; end
    end
    mixes_in_class_methods(ClassMethods)
  end
end
