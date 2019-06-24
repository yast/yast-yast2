module  Y2Firewall
  class Firewalld
    # Extends the base class with metaprogramming methods which defines some
    # attributes common logic.
    module Relations
      def enable_modifications_cache
        # Return an array with all the modified attributes/relations
        define_method "modified" do
          @modified ||= []
        end

        # Mark the given attribute as modified.
        define_method "modified!" do |item|
          @modified << item unless modified.include?(item)
        end

        # Return whether the object has been modified or not. If an argument is
        # given then it returns whether the given attribute or relation has
        # been modififed.
        define_method "modified?" do |*item|
          return !modified.empty? if item.empty?

          modified.include?(item.first)
        end

        # Reset all the modifications
        define_method "untouched!" do
          @modified = []
        end
      end

      # Defines a set of methods to operate over single-value firewalld
      # attributes like name, description, default_zone... Bang! methods
      # apply the object modifications into the firewalld configuration
      # using the firewalld API.
      #
      # A modifications cache can be enable with the cache param.
      #
      # @example
      #
      #   class Zone
      #     extend Relations
      #
      #     has_attributes :short, :description, :target, cache: true
      #   end
      #
      #   zone = Zone.new
      #
      #   # Return all the declared attributes
      #   zone.attributes #=> [:short, :description, :target]
      #   # Read all the attributes initializing the object
      #   zone.read_attributes
      #   # Obtain the configured zone name (not the object one)
      #   zone.current_short
      #   # Returns whether the zone has been modified since last read or write
      #   zone.modified? #=> false
      #   # Modifies the zone target
      #   zone.target = "DROP"
      #   zone.modified? #=> true
      #   # Apply all the attributes changes in firewalld
      #   zone.apply_attributes_changes!
      #   zone.modified? #=> false
      #   zone.target = "DROP"
      #   zone.modified? #=> true
      #   Reset all the modifications
      #   zone.untouched!
      #   zone.modified? #=> false
      #
      # @param attributes [Array<Symbol>] relation or attribute names
      # @param scope [String, nil] prepend some API calls with the given scope
      # @param cache [Boolean] if enabled will define some methods for caching
      #   the object modifications
      def has_attributes(*attributes, scope: nil, cache: false) # rubocop:disable Naming/PredicateName
        scope_method = scope ? "#{scope}_" : ""
        enable_modifications_cache if cache
        define_method "attributes" do
          attributes
        end

        attributes.each do |attribute|
          attr_reader attribute

          define_method "#{attribute}=" do |item|
            return item if public_send(attribute) == item
            instance_variable_set("@#{attribute}", item)

            modified!(attribute) if cache
          end

          define_method "current_#{attribute}" do
            params = ["#{scope_method}#{attribute}"]
            params << name if respond_to?("name")
            api.public_send(*params)
          end
        end

        define_method "read_attributes" do
          attributes.each { |a| instance_variable_set("@#{a}", public_send("current_#{a}")) }
          true
        end

        define_method "apply_attributes_changes!" do
          attributes.each do |attribute|
            next if cache && !modified?(attribute)
            params = ["modify_#{scope_method}#{attribute}"]
            params << name if respond_to?("name")
            params << public_send(attribute)
            api.public_send(*params)
          end
          true
        end
      end

      # Defines a set of methods to operate over array based firewalld
      # attributes like services, interfaces, protocols, ports... Bang! methods
      # apply the object modifications into the firewalld configuration
      # using the firewalld cmdline API.
      #
      # A modifications cache can be enable with the cache param.       #
      #
      # @example
      #
      #   class Zone
      #     extend Relations
      #
      #     has_many :services, cache: true
      #   end
      #
      #   zone = Zone.new
      #
      #   # Return all the declared relations
      #   zone.relations #=> [:services]
      #   # Read all the relations initializing the object
      #   zone.read_relations
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
      #   # Apply all the relations changes
      #   zone.apply_relations_changes!
      #
      # @param relations [Array<Symbol>] relation or attribute names
      # @param scope [String, nil] prepend some API calls with the given scope
      # @param cache [Boolean] if enabled will define some methods for caching
      #   the object modifications
      def has_many(*relations, scope: nil, cache: false) # rubocop:disable Naming/PredicateName
        scope = "#{scope}_" if scope
        enable_modifications_cache if cache

        define_method "relations" do
          relations
        end

        define_method "apply_relations_changes!" do
          relations.each { |r| public_send("apply_#{r}_changes!") }
          true
        end

        define_method "read_relations" do
          relations.each { |r| instance_variable_set("@#{r}", public_send("current_#{r}")) }
          true
        end

        relations.each do |relation|
          relation_singularized = relation.to_s.sub(/s$/, "")
          attr_reader relation

          define_method "#{relation}=" do |item|
            return item if public_send(relation) == item
            instance_variable_set("@#{relation}", item)

            modified!(relation) if cache
          end

          define_method "add_#{relation_singularized}" do |item|
            return public_send(relation) if public_send(relation).include?(item)
            modified!(relation) if cache
            public_send(relation) << item
          end

          define_method "remove_#{relation_singularized}" do |item|
            if public_send(relation).delete(item)
              modified!(relation) if cache
              return public_send(relation)
            end

            public_send(relation)
          end

          define_method "current_#{relation}" do
            if scope
              api.public_send("#{scope}#{relation}", name)
            else
              api.public_send("list_#{relation}", name)
            end
          end

          define_method "add_#{relation_singularized}!" do |item|
            api.public_send("add_#{scope}#{relation_singularized}", name, item)
          end

          define_method "remove_#{relation_singularized}!" do |item|
            api.public_send("remove_#{scope}#{relation_singularized}", name, item)
          end

          define_method "add_#{relation}!" do
            public_send("#{relation}_to_add").map { |i| public_send("add_#{relation_singularized}!", i) }
          end

          define_method "remove_#{relation}!" do
            public_send("#{relation}_to_remove").map { |i| public_send("remove_#{relation_singularized}!", i) }
          end

          define_method "#{relation}_to_add" do
            public_send(relation) - public_send("current_#{relation}")
          end

          define_method "#{relation}_to_remove" do
            public_send("current_#{relation}") - public_send(relation)
          end

          define_method "apply_#{relation}_changes!" do
            return if cache && !modified?(relation)
            public_send("remove_#{relation}!")
            public_send("add_#{relation}!")

            modified.delete(relation)
          end
        end
      end
    end
  end
end
