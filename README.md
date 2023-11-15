# Trophonius

A lightweight pure ruby link between Ruby (on Rails) and FileMaker using the FileMaker Data-API.

Do you need support connecting your FileMaker database?
Or do you have an awesome ruby project in mind?

Let us know if we can help.

[FileMaker Developer](https://kempenautomatisering.com/)

[Ruby (on Rails) development](https://kempenautomatisering.com/Ruby-Development)

# Installation

Install the gem yourself

```ruby
 gem install trophonius
```

Or add to your gemfile

```ruby
 gem 'trophonius', '~> 2.1'
```

And run bundle install

# Configuration

To begin using the gem create a configuration file in the initializers folder called trophonius.rb.
This file should contain all the information the Data-API needs to setup a connection to your database.

To generate this file automatically in a rails app you can use the generator:

```bash
rails g trophonius --host location_to.your_filemakerserver.com --database Name_of_your_database
```

Where --host should contain a url to your FileMaker server and --database should contain the name of your database

Example of the initializer file:
```ruby
Trophonius.configure do |config|
  config.host = "location_to.your_filemakerserver.com"
  config.database = "Name_of_your_database"
  config.username = "Username to Access the Database" # or Rails.application.credentials.dig(:username) (requires >= Rails 5.2)
  config.password = "Y0urAmaz1ngPa$$w0rd" # or Rails.application.credentials.dig(:password) (requires >= Rails 5.2)
  config.count_result_script = "script that can be used to count the results (optional)"
  config.redis_connection = true # default false, true if you want to store the token in redis
  config.ssl = true # or false depending on whether https or http should be used
  config.fm_18 = true # use if FileMaker server version >= 18, default true
  config.debug = false # will output more information when true
  config.pool_size = ENV.fetch('trophonius_pool', 5) # use multiple data api connections with a loadbalancer to improve performance
  # USE THE NEXT OPTION WITH CAUTION
  config.local_network = true # if true the ssl certificate will not be verified to allow for self-signed certificates
end
```

# Usage

Trophonius is setup to feel like ActiveRecord. You can choose to create a model for every table in your FileMaker app. Just make sure to include the name of the layout the model should look at:

```ruby
class MyModel < Trophonius::Model
  config layout_name: "MyModelsLayout"
end
```

You can also generate a model automatically using the following command:

```bash
rails g trophonius_model --model MyModel --layout MyModelsLayout
```

Where --model should contain the name you want to give to your model and --layout should contain the name of the layout on which this model should be based on


Or if your layout contains non-modifiable fields:

```ruby
class MyModel < Trophonius::Model
  config layout_name: "MyModelsLayout", non_modifiable_fields: ["PrimaryKey", "RecordID"]
end
```

## Field names

Since FileMaker allows anything to be a field name, Trophonius changes your fieldnames slightly to work like methods for the record. Trophonius changes your field names to a rubystyle, snake_cased name. To retrieve the translations you can use the method MyModel.translations. To use the translations in the create, where and edit methods, Trophonius requires at least one record to exist in order to create the translations.
This means that if two of your fields have the same name only one of those fields will be converted to a method, i.e. "New Field" and "New (Field)" will become both "new_field".

## Create records

To create a new record in the FileMaker database you only have to call the create method:

```ruby
  MyModel.create(field_one: "Data", number_field: 1)
```

The new record will be created immediately and filled with the provided data. The fieldnames are the same as the names in FileMaker. If the fieldname in FileMaker contains non-word characters, the fieldname should be in quotes. This method returns the created record as a Trophonius::Record instance. If you have a portal on your layout, you can fill the portal by adding a portal_data parameter:

```ruby
  MyModel.create(field_one: "Data", number_field: 1, portal_data: {
    "MyPortalOccurrenceName" => [
      { "portalField" => "value" },
      { "portalField" => "value2" },
      { "portalField" => "value4" }
    ]
  })
```

The field in your portal_data parameter have to be the same as the fieldnames in FileMaker, currently the translations don't work. You should also add

## Get records

Trophonius allows multiple ways to get records. The easiest ways are either .all or .first, which respectively return all records (if you have a foundcount script) or the first 1000000 records or only the first record.

```ruby
  MyModel.all # all records
  MyModel.first # first record
```

If you want a more restricted set of records or a specific record you might want to use the find functionality. To find a single specific record the .find method can be used. This method requires you to provide the recordid you would like to retrieve from FileMaker. When you want to find a set of records where a condition holds, the .where method should be used. This method returns all records where the condition holds, or an empty set if there are no records with this condition.

```ruby
  record = MyModel.find(100) # Record with recordID 100 (if available)
  MyModel.where(number_field: 100).to_a # Records where NumberField is 100 (if any)
  record.portal.each do |portal_record|
    portal_record.child_field
  end
```

If a condition requires multiple statements to be true, you can simply add multiple fields in the same where:

```ruby
 record = MyModel.find(100) # Record with recordID 100 (if available)
 MyModel.where(number_field: 100, date_field: Date.today.strftime('%m/%d/%Y')).to_a # Records where NumberField is 100 and date_field contains the date of today(if any)
 record.portal.each do |portal_record|
   portal_record.child_field
 end
```

### Omit records

If you want to find records without the specified query you can use the "not" method. This method will add an omit find request to the query. If the query gets executed, FileMaker will return the records where the condition does not hold.

```ruby
  MyModel.not(number_field: 100).to_a # Records where NumberField is not 100 (if any)
```

### Or find request

```ruby
  MyModel.where(number_field: 100).or(number_field: 101).to_a # Records where NumberField is 100 or 101 (if any)
```

### Sorted find request

```ruby
  MyModel.where(number_field: 100).sort(number_field: 'ascend').to_a # Records where NumberField is 100 sorted by number_field ascending (if any)
```

## Update records

To update the data of a record you can find a record in the FileMaker database and use the assignment operator on it's fields. A field can be accessed in two ways: if the field does not contain any non-word characters it is available as method for the record. Otherwise it is available as a key using the [] operator.
Once all fields are set, run the save method to store the new data in FileMaker.

```ruby
  record = MyModel.find(100) # or use MyModel.where and loop over the RecordSet
  record.field_one = "New Value"
  record.number_field = 42
  record["Field With Spaces and Non-word Characters!"] = "New value" # or record.field_with_spaces_and_non_word_characters
  record.save
```

## Uploading a file to a container

To upload a file to a container field you can use the upload method on a record. The first parameter, container_name, requires a string containing the name of the container field in filemaker, this process is case sensitive so containerfield ≠ ContainerField. The second parameter is the repetition of the container field (default value is 1). The third parameter, file, is the actual File or Tempfile object you want to upload to your container.

```ruby
  record = MyModel.find(100) # or use MyModel.where and loop over the RecordSet
  record.upload(container_name: 'MyContainerField', container_repetition: 1, file: params[:uploaded_file].tempfile)
```

## Delete records

Deleting a record is as simple as finding the record to delete and calling the delete method:

```ruby
  record_to_delete = MyModel.find(100)
  record_to_delete.delete
```

## Running a script

To run a FileMaker script from the context of a model you can call the run_script method. This method accepts an optional scriptparameter required by the FileMaker script. The method returns the script result, set by the Exit Script script step in FileMaker.

```ruby
  MyModel.run_script(script: "My Awesome Script", scriptparameter: "ScriptParameter") #the script parameter is optional
```

## Date and Time

The FileMaker Data API requires dates to be formatted as MM/DD/YYYY. To make this easier Trophonius adds "to_fm" methods to the Date and Time classes to format these types more easily.

```ruby
 Date.today.to_fm
 Time.now.to_fm
 Date.from_fm(filemakerDateField)
```

## Disconnecting from the Data API

To close the connection to the FileMaker server simply call:

```ruby
  Trophonius::Connection.disconnect
```

# Upgrading to 2.0

Trophonius 2.0 has been released 🎉
This introduced one breaking change: the parameters "portalData" for the create and update methods have been renamed to "portal_data" to conform to Rubys naming conventions

# To do

- [x] Better portal support (get supported)
- [x] Support portal set field directly (create)
- [ ] Support portal set field directly (other actions)
- [x] Better chainable where queries
- [x] Omit queries
- [x] Or queries
- [x] Store token in Redis
- [x] More container support
- [x] Remove non_modifiable_fields requirement from Model
- [x] FileMaker sorting
- [x] has_many/belongs_to relationships between models
- [ ] has_many/belongs_to readme

# Contributing

A contribution can be made by forking the repository. Once you are finished developing/testing in your fork you can submit a pull request.

# LICENSE

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

Copyright 2019 Kempen Automatisering

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
