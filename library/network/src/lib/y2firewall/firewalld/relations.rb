module  Y2Firewall
  class Firewalld
    module Relations
      def has_many(*args)
        args.each do |relation|
          relation_singularized = relation.to_s.gsub(/s$/,"")
          class_eval("attr_accessor :#{relation}")

          define_method "add_#{relation_singularized}" do |relation_name|
            return eval("#{relation}") if eval("#{relation}").include?(relation_name)

            eval("#{relation}") << relation_name
          end

          define_method "remove_#{relation_singularized}" do |relation_name|
            return eval("#{relation}") if eval("#{relation}").delete(relation_name)

            eval("#{relation}")
          end

          define_method "current_#{relation}" do
            eval("api.list_#{relation}(name)")
          end

          define_method "add_#{relation_singularized}!" do |relation_name|
            eval("api.add_#{relation_singularized}(name, relation_name)")
          end

          define_method "remove_#{relation_singularized}!" do |relation_name|
            eval("api.remove_#{relation_singularized}(name, relation_name)")
          end

          define_method "add_#{relation}!" do
            eval("#{relation}_to_add").map { |i| eval("add_#{relation_singularized}!(i)") }
          end

          define_method "remove_#{relation}!" do
            eval("#{relation}_to_remove").map { |i| eval("remove_#{relation_singularized}!(i)") }
          end

          define_method "#{relation}_to_add" do
            eval("#{relation}") - eval("current_#{relation}")
          end

          define_method "#{relation}_to_remove" do
            eval("current_#{relation}") - eval("#{relation}")
          end
        end
      end
    end
  end
end
