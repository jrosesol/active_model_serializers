# frozen_string_literal: true

require 'active_model/serializer/lazy_association'

module ActiveModel
  class Serializer
    # This class holds all information about serializer's association.
    #
    # @api private
    Association = Struct.new(:reflection, :association_options) do
      attr_reader :lazy_association
      delegate :object, :include_data?, :virtual_value, :collection?, to: :lazy_association

      def initialize(*)
        super
        @lazy_association = LazyAssociation.new(reflection, association_options)
      end

      # @return [Symbol]
      delegate :name, to: :reflection

      # @return [Symbol]
      def key
        reflection_options.fetch(:key, name)
      end

      # @return [True,False]
      def key?
        reflection_options.key?(:key)
      end

      # @return [Hash]
      def links
        reflection_options.fetch(:links) || {}
      end

      # @return [Hash, nil]
      # This gets mutated, so cannot use the cached reflection_options
      def meta
        reflection.options[:meta]
      end

      def belongs_to?
        reflection.foreign_key_on == :self
      end

      def polymorphic?
        true == reflection_options[:polymorphic]
      end

      # @api private
      def serializable_hash(adapter_options, adapter_instance)
        association_serializer = lazy_association.serializer
        return virtual_value if virtual_value
        association_object = association_serializer && association_serializer.object
        return unless association_object

        serializer_name = association_serializer.json_key
        if association_serializer.root
          # hack : we have to grab the serializer fields for the association from the class name
          serializer_name = association_serializer.object.class.to_s.split('::ActiveRecord_Associations_CollectionProxy', 0).first.pluralize.downcase
        end

        adapter_sub_options = adapter_options.deep_dup
        fields = adapter_options.fetch(:fields, nil)
        sub_fields = []
        if fields.is_a?(Hash)
          sub_fields = fields.fetch(association_serializer.json_key, nil)
        else
          fields.each do |f|
            sub_fields = f.fetch(serializer_name, nil) if f.is_a?(Hash)
            break if sub_fields.present?
          end unless fields.nil?
        end

        if sub_fields.present?
          adapter_sub_options[:fields] = sub_fields.collect { |f| f.to_sym }
        else
          adapter_sub_options = {}
        end

        serialization = association_serializer.serializable_hash(adapter_options, adapter_sub_options, adapter_instance)

        if polymorphic? && serialization
          polymorphic_type = association_object.class.name.underscore
          serialization = { type: polymorphic_type, polymorphic_type.to_sym => serialization }
        end

        serialization
      end

      private

      delegate :reflection_options, to: :lazy_association
    end
  end
end
