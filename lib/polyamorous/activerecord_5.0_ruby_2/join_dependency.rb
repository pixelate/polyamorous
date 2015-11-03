# active_record_5.0_ruby_2/join_dependency.rb

module Polyamorous
  module JoinDependencyExtensions

    # Replaces ActiveRecord::Associations::JoinDependency#build.
    #
    def build(associations, base_klass)
      associations.map do |name, right|
        if name.is_a? Join
          reflection = find_reflection base_klass, name.name
          reflection.check_validity!
          klass = if reflection.polymorphic?
            name.klass || base_klass
          else
            reflection.klass
          end
          JoinAssociation.new(reflection, build(right, klass), name.klass, name.type)
        else
          reflection = find_reflection base_klass, name
          reflection.check_validity!
          if reflection.polymorphic?
            raise ActiveRecord::EagerLoadPolymorphicError.new(reflection)
          end
          JoinAssociation.new reflection, build(right, reflection.klass)
        end
      end
    end

    def find_join_association_respecting_polymorphism(reflection, parent, klass)
      if association = parent.children.find { |j| j.reflection == reflection }
        unless reflection.polymorphic?
          association
        else
          association if association.base_klass == klass
        end
      end
    end

    def build_join_association_respecting_polymorphism(reflection, parent, klass)
      if reflection.polymorphic? && klass
        JoinAssociation.new(reflection, self, klass)
      else
        JoinAssociation.new(reflection, self)
      end
    end

    # Replaces ActiveRecord::Associations::JoinDependency#join_constraints
    # in order to call #make_joins instead of #make_inner_joins.
    #
    def join_constraints(outer_joins)
      joins = join_root.children.flat_map { |child|
        make_joins(join_root, child)
      }
      joins.concat outer_joins.flat_map { |oj|
        if join_root.match? oj.join_root
          walk(join_root, oj.join_root)
        else
          oj.join_root.children.flat_map { |child|
            make_outer_joins(oj.join_root, child)
          }
        end
      }
    end

    # Replaces ActiveRecord::Associations::JoinDependency#make_inner_joins.
    #
    def make_joins(parent, child)
      [
        make_constraints(
          parent, child, child.tables, child.join_type || Arel::Nodes::InnerJoin
        )
      ] + child.children.flat_map { |c| make_inner_joins(child, c) }
    end

    private :make_joins

    module ClassMethods
      # Prepended before ActiveRecord::Associations::JoinDependency#walk_tree.
      #
      def walk_tree(associations, hash)
        if TreeNode === associations
          associations.add_to_tree(hash)
        else
          super(associations, hash)
        end
      end
    end

  end
end
