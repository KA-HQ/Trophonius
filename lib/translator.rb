# require 'time'
# require 'date_time'
# require 'date'
require 'active_support/inflector'
module Trophonius
  module Translator
    def methodize_field(field_name)
      ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(field_name), separator: '_').downcase
    end

    def methodize_portal_field(field_name)
      ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(field_name.gsub(/\w+::/, '').to_s), separator: '_')
    end

    def portal_relation_name(first_related_record)
      return '' if first_related_record.nil?

      first_related_record.keys.map{ |f| f[/.*(?=::)/] }.tally.max_by(&:last).first
    end
  end
end
