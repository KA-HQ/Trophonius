require 'rails'

module Trophonius
  class ModelGenerator < ::Rails::Generators::Base
    namespace 'trophonius_model'

    class_option :model, type: :string, default: 'MyModel'
    class_option :layout, type: :string, default: 'MyModelsLayout'

    source_root File.expand_path('../templates', __FILE__)

    desc 'add the config file'

    def copy_model_file
      @model = options['model']
      @layout = options['layout']
      create_file "app/models/#{@model.downcase}.rb",
                  "class #{@model.humanize} < Trophonius::Model
  config layout_name: '#{@layout}'
end"
    end
  end
end
