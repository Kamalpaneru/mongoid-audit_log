module Mongoid
  module AuditLog
    class Changes
      attr_reader :model
      delegate :blank?, :present?, :to => :all

      def self.ch_ch_ch_ch_ch_changes
        puts "turn and face the strange changes"
      end

      def self.extract_from(value)
        if value.is_a?(Hash)
          raise ArgumentError, 'does not support hashes'
        elsif value.is_a?(Enumerable)
          changes = value.map do |model|
            Mongoid::AuditLog::Changes.new(model).all
          end

          changes.reject(&:blank?)
        else
          Mongoid::AuditLog::Changes.new(value).all
        end
      end

      def self.clean_fields(*disallowed_fields)
        options = disallowed_fields.extract_options!

        unless options.has_key?(:from)
          raise ArgumentError, ':from is a required argument'
        end

        changes = options[:from]

        if changes.is_a?(Hash)
          changes.except(*disallowed_fields).inject({}) do |memo, t|
            key, value = *t
            memo.merge!(key => clean_fields(*disallowed_fields, :from => value))
          end
        elsif changes.is_a?(Enumerable)
          changes.map { |c| clean_fields(*disallowed_fields, :from => c) }
        else
          changes
        end
      end

      def initialize(model)
        @model = model
      end

      def all
        @all ||= if model.blank? || !model.changed?
                   {}
                 else
                   result = model.changes
                   result.merge!(embedded_changes) unless embedded_changes.empty?
                   Mongoid::AuditLog::Changes.clean_fields('_id', 'updated_at', :from => result)
                 end
      end
      alias_method :read, :all

      private

      def embedded_changes
        @embedded_changes ||= model.embedded_relations.inject({}) do |memo, t|
          name = t.first
          embedded = model.send(name)
          changes = Mongoid::AuditLog::Changes.extract_from(embedded)

          if embedded.present? && changes.present?
            memo[name] = changes
          end

          memo
        end
      end
    end
  end
end
