require 'psych'

module SensData
  RequiredKeys = ['avail_stores']
  class ParseError < IOError; end
  #SensitiveDataFile = "../../../../sens_data/tinkit_setup_data"
  #Set up which datastores to use for testing
  #user names and passwords are stored elsewhere for security
  def self.load(f)
    sens_file = File.expand_path(f) #(SensData::SensitiveDataFile)
    raise IOError, "Sensitive data file not found: #{sens_file.inspect}" unless File.exist? sens_file
 
    ##Uncomment to create the file with data
    #data = { "TinkitStore" => { "CouchDb" => { "default" => { "user" => some user, "pw" => secret pw } } } }
    #File.open(SensFile, 'w+'){|f| f.write data.to_json}
    #sens_json = File.open(sens_file, 'r') {|f| f.read }
    #JSON.parse(sens_json)
    sens_yaml = File.open(sens_file, 'r') {|f| f.read }
    config_data = Psych.load(sens_yaml)
    raise ParseError, "Unable to parse file:#{sens_file.inspect} is it valid Yaml?" unless config_data
    RequiredKeys.each do |key|
      raise ParseError, "Required key: #{key} not found in data file: #{sens_file.inspect}" unless config_data.keys.include? key
    end 
    config_data
  end
end
