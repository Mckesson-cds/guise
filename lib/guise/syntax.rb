require 'active_support/concern'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/string/inflections'

module Guise
  module Syntax
    # Setup the moodel's `guises` association. Given the following setup:
    #
    # ```ruby
    # class User < ActiveRecord::Base
    #   has_guises :DeskWorker, :MailForwarder, association: :roles, attribute: :value
    # end
    # ```
    #
    # The following is configured:
    #
    # * `has_many` association named according to the `:association` option.
    # * `User.desk_workers` and `User.mail_forwarders` model scopes.
    # * `User#has_guise?` that checks if a user is a particular type.
    # * `User#desk_worker?`, `User#mail_forwarder?` that proxy to `User#has_guise?`.
    # * `User#has_guises?` that checks if a user has records for all the types
    #   supplied. This is aliased to `User#has_roles?`.
    # * `User#has_any_guises?` that checks if a user has records for any of the
    #   types supplied. This is aliased to `User#has_any_roles?`.
    #
    # @param [Array<Symbol, String>] *guises names of guises that should be allowed
    def has_guises(*guises)
      include Introspection

      options = guises.last.is_a?(Hash) ? guises.pop : {}

      guises      = guises.map(&:to_s)
      association = options.fetch(:association)
      attribute   = options.fetch(:attribute)
      join_table  = options[:table_name] || association

      Guise.registry[self.name] = {
        names: guises,
        association: association,
        attribute: attribute
      }

      guises.each do |guise|
        method_name = guise.underscore
        scope method_name.pluralize, -> { select("#{self.table_name}.*").joins(association).where(join_table => { attribute => guise }) }

        define_method "#{method_name}?" do
          has_guise?(guise)
        end
      end

      has_many association, options.except(:association, :attribute, :table_name)

      if association != :guises
        association_singular = association.to_s.singularize

        alias_method :guises, association
        alias_method :guises=, "#{association}="
        alias_method :guise_ids, "#{association_singular}_ids"
        alias_method :guise_ids=, "#{association_singular}_ids="
        alias_method "has_#{association_singular}?", :has_guise?
        alias_method "has_#{association}?", :has_guises?
        alias_method "has_any_#{association}?", :has_any_guises?
      end
    end

    # Specifies that the calling model class is a subclass a model configured
    # with {Syntax#has_guises has_guises} specified by `class_name`.
    #
    # Configures the caller with the correct `default_scope`. For example:
    #
    # ```ruby
    # class DeskWorker < User
    #   guise_of :User
    # end
    # ```
    #
    # Is equivalent to:
    #
    # ```ruby
    # class DeskWorker < User
    #   default_scope -> { desk_workers }
    #
    #   after_initialize do
    #     self.guises.build(title: 'DeskWorker')
    #   end
    #
    #   after_create do
    #     self.guises.create(title: 'DeskWorker')
    #   end
    # end
    # ```
    #
    # @param [String, Symbol] class_name name of the class configured with
    #   {Syntax#has_guises has_guises} that caller is a subclass of.
    def guise_of(class_name)
      options = Guise.registry[class_name]

      if options.nil?
        raise ArgumentError, "no guises defined on #{class_name}"
      end

      default_scope -> { send(model_name.plural) }

      after_initialize SourceCallback.new(self.name, options[:attribute])
    end

    # Configures the other end of the association defined by {Syntax#has_guises
    # has_guises}. Defines equivalent scopes defined on the model configured
    # with {Syntax#has_guises has_guises}
    #
    # @param [Symbol, String] class_name name of the class configured with
    #   {Syntax#has_guises has_guises}
    # @param [Hash] options options to configure the `belongs_to` association.
    # @option options [false] :validate specify `false` to skip
    #   validations for the `:attribute` specified in {Syntax#has_guises
    #   has_guises}
    def guise_for(class_name, options = {})
      guise_options = Guise.registry[class_name]

      if guise_options.nil?
        raise ArgumentError, "no guises defined on #{class_name}"
      end

      association = class_name.to_s.underscore.to_sym
      guises      = guise_options[:names]
      attribute   = guise_options[:attribute]
      foreign_key = options[:foreign_key] || "#{class_name.to_s.underscore}_id"

      belongs_to association, options.except(:validate)

      guises.each do |guise|
        scope guise.underscore.pluralize, -> { where(attribute => guise) }
      end

      if options[:validate] != false
        validates attribute, uniqueness: { scope: foreign_key }, presence: true, inclusion: { in: guises }
      end
    end

    def scoped_guise_for(class_name)
      guise_options = Guise.registry[class_name]

      if guise_options.nil?
        raise ArgumentError, "no guises defined on #{class_name}"
      end

      attribute = guise_options[:attribute]
      parent_name = table_name.classify

      value = guise_options[:names].detect do |guise|
        guise == model_name.to_s.chomp(parent_name)
      end

      default_scope -> { where(attribute => value) }

      after_initialize AssociationCallback.new(value, attribute)
    end
  end
end
