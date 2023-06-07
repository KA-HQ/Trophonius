require 'active_support/all'
module Trophonius
  module Translator
    def methodize_field(field_name)
      ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(field_name), separator: '_').downcase
    end

    def methodize_portal_field(field_name)
      ActiveSupport::Inflector.parameterize(ActiveSupport::Inflector.underscore(field_name.gsub(/\w+::/, '').to_s), separator: '_')
    end
  end
end
