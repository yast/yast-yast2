module  Y2Firewall
  class Firewalld
    # Extends the base class with metaprogramming methods which defines some
    # attributes common logic.
    module Relations
      # Defines a set of methods to operate over array based firewalld
      # attributes like services, interfaces, protocols, ports..
      #
      # @example
      #
      #   class Zone
      #     extend Relations
      #
      #     has_many :services
      #   end
      #
      #   zone = Zone.new
      #
      #   # Adds the "ssh" service into the zone object if not present
      #   zone.add_service("ssh")
      #   # Removes the "ssh" service from the zone object
      #   zone.remove_service("ssh")
      #   # List of current firewalld configured services
      #   zone.current_services
      #   # Adds the service "ssh" definitely
      #   zone.add_service!("ssh")
      #   # Removes the service "ssh" definitely
      #   zone.remove_service!("ssh")
      #   Adds definitely the list of services_to_add
      #   zone.add_services!
      #   Removes definitely the list of services_to_add
      #   zone.remove_services!
      #   # Returns the list of services added after read
      #   zone.services_to_add
      #   # Returns the list of services removed after read
      #   zone.services_to_remove
      #   # Apply the changes (remove_services! && add_services!)
      #   zone.apply_services_changes!
      #
      # @param args [Array<Symbol] relation or attribute names
      def has_many(*args) # rubocop:disable Style/PredicateName
        args.each do |relation|
          relation_singularized = relation.to_s.gsub(/s$/, "")
          class_eval("attr_accessor :#{relation}")

          define_method "add_#{relation_singularized}" do |relation_name|
            return instance_eval(relation.to_s) if instance_eval(relation.to_s).include?(relation_name)

            instance_eval(relation.to_s) << relation_name
          end

          define_method "remove_#{relation_singularized}" do |relation_name|
            return instance_eval(relation.to_s) if instance_eval(relation.to_s).delete(relation_name)

            instance_eval(relation.to_s)
          end

          define_method "current_#{relation}" do
            instance_eval("api.list_#{relation}(name)")
          end

          define_method "add_#{relation_singularized}!" do |_relation_name|
            instance_eval("api.add_#{relation_singularized}(name, relation_name)")
          end

          define_method "remove_#{relation_singularized}!" do |_relation_name|
            instance_eval("api.remove_#{relation_singularized}(name, relation_name)")
          end

          define_method "add_#{relation}!" do
            instance_eval("#{relation}_to_add").map { |_i| instance_eval("add_#{relation_singularized}!(i)") }
          end

          define_method "remove_#{relation}!" do
            instance_eval("#{relation}_to_remove").map { |_i| instance_eval("remove_#{relation_singularized}!(i)") }
          end

          define_method "#{relation}_to_add" do
            instance_eval(relation.to_s) - instance_eval("current_#{relation}")
          end

          define_method "#{relation}_to_remove" do
            instance_eval("current_#{relation}") - instance_eval(relation.to_s)
          end

          define_method "apply_#{relation}_changes!" do
            instance_eval("remove_#{relation}!")
            instance_eval("add_#{relation}!")
          end
        end
      end
    end
  end
end
