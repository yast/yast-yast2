module  Y2Firewall
  class Firewalld
    # Extends the base class with metaprogramming methods which defines some
    # attributes common logic.
    module Relations
      # Defines a set of methods to operate over array based firewalld
      # attributes like services, interfaces, protocols, ports... Bang! methods
      # applies the object modifications into the firewalld zone using the
      # Firewalld API.
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
      #   # Adds the service "ssh" definitely into the firewalld zone
      #   zone.add_service!("ssh")
      #   # Removes the service "ssh" definitely from firewalld zone
      #   zone.remove_service!("ssh")
      #   Loop through all the services were added to the zone object since
      #   read adding them definitely to firewalld
      #   zone.add_services!
      #   Loop through all the services were removed from the zone object since
      #   read adding them to firewalld
      #   zone.remove_services!
      #   # Returns the list of services added after read
      #   zone.services_to_add
      #   # Returns the list of services removed after read
      #   zone.services_to_remove
      #   # Apply the changes (remove_services! && add_services!)
      #   zone.apply_services_changes!
      #
      # @param args [Array<Symbol] relation or attribute names
      def has_many(*relations) # rubocop:disable Style/PredicateName
        relations.each do |relation|
          relation_singularized = relation.to_s.sub(/s$/, "")
          class_eval("attr_accessor :#{relation}")

          define_method "add_#{relation_singularized}" do |item|
            return public_send(relation.to_s) if public_send(relation.to_s).include?(item)

            public_send(relation.to_s) << item
          end

          define_method "remove_#{relation_singularized}" do |item|
            return public_send(relation.to_s) if public_send(relation.to_s).delete(item)

            public_send(relation.to_s)
          end

          define_method "current_#{relation}" do
            api.public_send("list_#{relation}", name)
          end

          define_method "add_#{relation_singularized}!" do |item|
            api.public_send("add_#{relation_singularized}", name, item)
          end

          define_method "remove_#{relation_singularized}!" do |item|
            api.public_send("remove_#{relation_singularized}", name, item)
          end

          define_method "add_#{relation}!" do
            public_send("#{relation}_to_add").map { |i| public_send("add_#{relation_singularized}!", i) }
          end

          define_method "remove_#{relation}!" do
            public_send("#{relation}_to_remove").map { |i| public_send("remove_#{relation_singularized}!", i) }
          end

          define_method "#{relation}_to_add" do
            public_send(relation.to_s) - public_send("current_#{relation}")
          end

          define_method "#{relation}_to_remove" do
            public_send("current_#{relation}") - public_send(relation.to_s)
          end

          define_method "apply_#{relation}_changes!" do
            public_send("remove_#{relation}!")
            public_send("add_#{relation}!")
          end
        end
      end
    end
  end
end
