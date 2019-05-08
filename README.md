# Trophonius

An easy to use link between Ruby (on Rails) and FileMaker using the FileMaker Data-API.

# Installation

Install the gem yourself

```ruby
 gem install trophonius
```

Or add to your gemfile

```ruby
 gem 'trophonius', '>= 1.0.0'
```

And run bundle install

# Configuration

To begin using the gem create a configuration file in the initializers folder called trophonius.rb.
This file should contain all the information the Data-API needs to setup a connection to your database. Example file:

```ruby
Trophonius.configure do |config|
  config.host = "location_to.your_filemakerserver.com"
  config.database = "Name_of_your_database"
  config.layout_name = "Name_of_the_general_Data_API_layout"
  config.username = "Username to Access the Database" # or Rails.application.credentials.dig(:username) (requires >= Rails 5.2)
  config.password = "Y0urAmaz1ngPa$$w0rd" # or Rails.application.credentials.dig(:password) (requires >= Rails 5.2)
  config.count_result_script = "script that can be used to count the results (optional)"
end
```

# Usage

Trophonius is setup to feel like ActiveRecord. You can choose to create a model for every table in your FileMaker app. Just make sure to include the name of the layout the model should look at:

```ruby
class MyModel < Trophonius::Model
  config layout_name: "MyModelsLayout"
end
```

Or if your layout contains non-modifiable fields:

```ruby
class MyModel < Trophonius::Model
  config layout_name: "MyModelsLayout", non_modifiable_fields: ["PrimaryKey", "RecordID"]
end
```

## Create records

To create a new record in the FileMaker database you only have to call the create method:

```ruby
  MyModel.create(FieldOne: "Data", NumberField: 1)
```

The new record will be created immediately and filled with the provided data. The fieldnames are the same as the names in FileMaker. If the fieldname in FileMaker contains non-word characters, the fieldname should be in quotes.

## Get records

Trophonius allows multiple ways to get records. The easiest ways are either .all or .first, which respectively return all records (if you have a foundcount script) or the first 1000000 records or only the first record.

```ruby
  MyModel.all # all records
  MyModel.first # first record
```

If you want a more restricted set of records or a specific record you might want to use the find functionality. To find a single specific record the .find method can be used. This method requires you to provide the recordid you would like to retrieve from FileMaker. When you want to find a set of records where a condition holds, the .where method should be used. This method returns all records where the condition holds, or an empty set if there are no records with this condition.

```ruby
  MyModel.find(100) # Record with recordID 100 (if available)
  MyModel.where(NumberField: 100) # Records where NumberField is 100 (if any)
```

## Update records

To update the data of a record you can find a record in the FileMaker database and use the assignment operator on it's fields. A field can be accessed in two ways: if the field does not contain any non-word characters it is available as method for the record. Otherwise it is available as a key using the [] operator.
Once all fields are set, run the save method to store the new data in FileMaker.

```ruby
  record = MyModel.find(100) # or use MyModel.where and loop over the RecordSet
  record.FieldOne = "New Value"
  record.NumberField = 42
  record["Field With Spaces and Non-word Characters!"] = "New value"
  record.save
```

## Delete records

Deleting a record is as simple as finding the record to delete and calling the delete method:

```ruby
  record_to_delete = MyModel.find(100)
  record_to_delete.delete
```

## Running a script

To run a FileMaker script from the context of a model you can call the run_script method. This method accepts an optional script_parameter required by the FileMaker script. The method returns the script result, set by the Exit Script script step in FileMaker.

```ruby
  MyModel.run_script("My Awesome Script", "ScriptParameter") #the script parameter is optional
```

# To do

- [ ] Better portal support
- [ ] Better chainable where queries
- [ ] Store token in Redis
- [ ] More container support
- [ ] Remove non_modifiable_fields requirement from Model

# Contributing

A contribution can be made by forking the repository. Once you are finished developing/testing in your fork you can submit a pull request.

# LICENSE

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

Copyright 2019 Kempen Automatisering

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
