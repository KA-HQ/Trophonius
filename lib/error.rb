require 'json'
require 'config'

module Trophonius
  module Trophonius::Error
    class RecordNotFoundError < StandardError; end # :nodoc:
    class FieldUnexistingError < NoMethodError; end # :nodoc:
    class ScriptUnexistingError < NoMethodError; end # :nodoc:
    class LayoutUnexistingError < NoMethodError; end # :nodoc:
    class InvalidTokenError < StandardError; end # :nodoc:
    class UnauthenticatedError < StandardError; end # :nodoc:
    class AuthenticationError < StandardError; end # :nodoc:
    class FieldNotModifiableError < StandardError; end # :nodoc:
    class ResponseNotYetImplementedError < StandardError; end # :nodoc:
    class UnknownFileMakerError < StandardError; end # :nodoc:
    class UserCanceledError < StandardError; end # :nodoc:
    class MemoryError < StandardError; end # :nodoc:
    class FileError < StandardError; end # :nodoc:
    class CommandError < StandardError; end # :nodoc:
    class ConnectionError < StandardError; end # :nodoc:
    class EmptyFindError < StandardError; end # :nodoc:
    class ValidationError < StandardError; end # :nodoc:
    class DateValueError < ValidationError; end # :nodoc:
    class TimeValueError < ValidationError; end # :nodoc:
    class NumberValueError < ValidationError; end # :nodoc:
    class ValueOutOfRangeError < ValidationError; end # :nodoc:
    class ValueNotUniqueError < ValidationError; end # :nodoc:
    class ValueNotExistingError < ValidationError; end # :nodoc:
    class ValueListNotExistingError < ValidationError; end # :nodoc:
    class ValueNotInValuelistError < ValidationError; end # :nodoc:
    class ValueFailedCalculationError < ValidationError; end # :nodoc:
    class RecordLockedError < ValidationError; end # :nodoc:
    class EntityLockedError < ValidationError; end # :nodoc:
    class MissingEntityError < ValidationError; end # :nodoc:

    ##
    # Throws an error corresponding to the error number
    # :args: error_id, more_info
    def self.throw_error(error_id, more_info = 0, layout_info = nil)
      case error_id
      when '-1'
        raise UnknownFileMakerError.new, 'Unknown Error Ocurred'
      when '0'
        raise UnknownFileMakerError.new, 'Unknown Error Ocurred'
      when '1'
        raise UserCanceledError.new, 'An outside source canceled the action'
      when '2'
        raise MemoryError.new, 'FileMaker encountered a memory error'
      when '3'
        raise CommandError.new, 'Command is unavailable (for example, wrong operating system or mode)'
      when '4'
        raise CommandError.new, 'Command is unknown'
      when '5'
        raise CommandError.new, 'Command is invalid, check your FileMaker script/calculation'
      when '6'
        raise FileError.new, 'File is read-only'
      when '7'
        raise MemoryError.new, 'FileMaker is running out of memory'
      when '8'
        raise RecordNotFoundError.new, 'Empty result'
      when '9'
        raise UnauthenticatedError.new, 'User has insufficient privileges'
      when '10'
        raise MissingEntityError.new, 'Requested data is missing'
      when '11'
        raise ValidationError.new, 'Name is not valid'
      when '12'
        raise ValidationError.new, 'Name already exists'
      when '13'
        raise EntityLockedError.new, 'File or object is in use'
      when '14'
        raise ValueOutOfRangeError.new, 'Out of range'
      when '15'
        raise NumberValueError.new, 'Cant divide by zero'
      when '16'
        raise CommandError.new, 'Operation failed; request retry (for example, a user query)'
      when '17'
        raise ValidationError.new, 'Attempt to convert foreign character set to UTF-16 failed'
      when '18'
        raise AuthenticationError.new, 'Client must provide account information to proceed'
      when '19'
        raise ValidationError.new, 'String contains characters other than A-Z, a-z, 0-9 (ASCII)'
      when '20'
        raise CommandError.new, 'Command/operation canceled by triggered script'
      when '21'
        raise CommandError.new, 'Request not supported (for example, when creating a hard link on a file system that does not support hard links)'
      when '100'
        raise MissingEntityError.new, 'File is missing'
      when '101'
        raise RecordNotFoundError.new, "Record #{more_info} was not found"
      when '102'
        raise FieldUnexistingError.new, 'Field does not exist' if more_info.zero?

        raise FieldUnexistingError.new, "Following field(s) #{more_info} do not exist on layout #{layout_info}"
      when '103'
        raise MissingEntityError.new, 'Relationship is missing'
      when '104'
        raise ScriptUnexistingError.new, 'Script does not exist'
      when '105'
        raise LayoutUnexistingError.new, 'Layout does not exist'
      when '106'
        raise MissingEntityError.new, 'Table is missing'
      when '107'
        raise MissingEntityError.new, 'Index is missing'
      when '108'
        raise ValueListNotExistingError.new, 'ValueList does not exist'
      when '109'
        raise MissingEntityError.new, 'Privilege set is missing'
        # when "110"
        # when "111"
        # when "112"
        # when "113"
        # when "114"
        # when "115"
        # when "116"
        # when "117"
        # when "118"
        # when "130"
        # when "131"
        # when "200"
      when '201'
        raise FieldNotModifiableError.new, 'Trying to write to a read-only field'
        # when "202"
        # when "203"
        # when "204"
        # when "205"
        # when "206"
        # when "207"
        # when "208"
        # when "209"
        # when "210"
        # when "211"
        # when "212"
        # when "213"
        # when "214"
        # when "215"
        # when "216"
        # when "217"
        # when "218"
        # when "300"
      when '301'
        raise RecordLockedError.new, 'Record is locked by a FileMaker client'
        # when "302"
        # when "303"
        # when "304"
        # when "306"
        # when "307"
        # when "308"
      when '400'
        raise EmptyFindError.new, '	Find criteria are empty'
      when '401'
        raise RecordNotFoundError.new, "Record #{more_info} was not found"
        # when "402"
      when '403'
        raise UnauthenticatedError.new, 'You are unauthenticated to perform this request'
        # when "404"
        # when "405"
        # when "406"
        # when "407"
        # when "408"
        # when "409"
        # when "410"
        # when "412"
        # when "413"
        # when "414"
        # when "415"
        # when "416"
        # when "417"
        # when "418"
      when '500'
        raise DateValueError.new, 'Date value does not meet validation entry options (hint make sure your date values are formatted as MM/DD/YYYY)'
      when '501'
        raise TimeValueError.new, 'Time value does not meet validation entry options'
      when '502'
        raise NumberValueError.new, 'Number value does not meet validation entry options'
      when '503'
        raise ValueOutOfRangeError.new, 'Value in field is not within the range specified in validation entry options'
      when '504'
        raise ValueNotUniqueError.new, 'Value in field is not unique, as required in validation entry options'
      when '505'
        raise ValueNotExistingError.new, 'Value in field is not an existing value in the file, as required in validation entry options'
      when '506'
        raise ValueNotInValuelistError.new, 'Value in field is not listed in the value list specified in validation entry options'
      when '507'
        raise ValueFailedCalculationError.new, 'Value in field failed calculation test of validation entry options'
        # when "508"
        # when "509"
        # when "510"
        # when "511"
        # when "512"
        # when "513"
        # when "600"
        # when "601"
        # when "602"
        # when "603"
        # when "700"
        # when "706"
        # when "707"
        # when "708"
        # when "711"
        # when "714"
        # when "715"
        # when "716"
        # when "717"
        # when "718"
        # when "719"
        # when "720"
        # when "721"
        # when "722"
        # when "723"
        # when "724"
        # when "725"
        # when "726"
        # when "727"
        # when "729"
        # when "730"
        # when "731"
        # when "732"
        # when "733"
        # when "734"
        # when "735"
        # when "736"
        # when "738"
        # when "800"
        # when "801"
        # when "802"
        # when "803"
        # when "804"
        # when "805"
        # when "806"
        # when "807"
        # when "808"
        # when "809"
        # when "810"
        # when "811"
        # when "812"
        # when "813"
        # when "814"
        # when "815"
        # when "816"
        # when "817"
        # when "819"
        # when "820"
        # when "821"
        # when "822"
        # when "823"
        # when "824"
        # when "825"
        # when "826"
        # when "827"
        # when "850"
        # when "851"
        # when "852"
        # when "853"
        # when "900"
        # when "901"
        # when "902"
        # when "903"
        # when "905"
        # when "906"
        # when "920"
        # when "921"
        # when "922"
        # when "923"
        # when "951"
      when '952'
        raise InvalidTokenError.new, 'Could not retrieve a valid token from FileMaker, check your FileMaker server'
        # when "954"
        # when "955"
        # when "956"
        # when "957"
        # when "958"
        # when "959"
        # when "960"
        # when "1200"
        # when "1201"
        # when "1202"
        # when "1203"
        # when "1204"
        # when "1205"
        # when "1206"
        # when "1207"
        # when "1208"
        # when "1209"
        # when "1210"
        # when "1211"
        # when "1212"
        # when "1213"
        # when "1214"
        # when "1215"
        # when "1216"
        # when "1217"
        # when "1218"
        # when "1219"
        # when "1220"
        # when "1221"
        # when "1222"
        # when "1223"
        # when "1224"
        # when "1225"
        # when "1300"
        # when "1301"
        # when "1400"
        # when "1401"
        # when "1402"
        # when "1403"
        # when "1404"
        # when "1405"
        # when "1406"
        # when "1407"
        # when "1408"
        # when "1409"
        # when "1413"
        # when "1414"
        # when "1450"
        # when "1451"
        # when "1501"
        # when "1502"
        # when "1503"
        # when "1504"
        # when "1505"
        # when "1506"
        # when "1507"
        # when "1550"
        # when "1551"
        # when "1626"
        # when "1627"
        # when "1628"
        # when "1629"
        # when "1630"
      when '1631'
        raise ConnectionError.new, 'An error occurred while attempting to connect to the FileMaker server'
        # when "1632"
        # when "1633"
      else
        raise ResponseNotYetImplementedError.new, "An unknown error has been encountered: err_no was #{error_id}"
      end
    end
  end
end
