require 'uri'
require 'couchrest'
require 'json'

require_relative 'sens_data'

module TinkitConfig
  @@config_file_location = nil
  
  TinkitTypeToMethod = {
    'couchdb' => {
      :method => :activate_couch,
      :args => ['host','user']
    }
  }


  class Resp
    attr_reader :success_flag, :type, :native
    def initialize(type, native)
      @type = type
      @native = native
      @success_flag = parse_resp(type, native)
    end

   #ToDo: Move Parsing functions to module in the datastore models
   def parse_resp(type, native)
     success_flag = case type
       when 'couchdb'
         resp = JSON.parse(native)
         if resp["db_name"]
           success_flag = true
         else
           success_flag = false
         end
     end
     success_flag
   end
  end

  def self.set_config_file_location(f)
    raise IOError, "Unable to locate file: #{f.inspect}, does it exist?" unless File.exist?(f)
    @@config_file_location = f
  end
    
  def self.activation(store_name, tinkit_store_name)
    config_data = SensData.load(@@config_file_location)
    avail_stores = config_data['avail_stores']
    raise NameError, "Store: #{store_name.inspect} was not found in the configuration file" unless avail_stores.keys.include? store_name
    store_data = avail_stores[store_name]
    store_type = store_data['type']

    method_data = TinkitTypeToMethod[store_type]
    method = method_data[:method]
    arg_names = method_data[:args]
    args = arg_names.inject({}) do |memo, arg|
      memo[arg.to_sym] = store_data[arg.to_s] 
      memo
    end
    args[:store_name] =  tinkit_store_name
    self.__send__(method, args)
  end

  def self.activate_couch(args)
    db_name = args[:store_name]
    host = args[:host]
    userinfo = args[:user]
    db_path = "/" + db_name
    url = URI::HTTP.build :userinfo => userinfo, :host => host, :path => db_path, :port => 5984
    CouchRest.database! url.to_s
    native_resp_json = `curl -sX GET #{url.to_s}`
    Resp.new('couchdb', native_resp_json)
  end

  def self.activate_stores(store_names, tinkit_store_name)
    raise "Configuration file location not set. Use:  #{self.name}.set_config_file_location(\"path/to/config/file\")" unless @@config_file_location
    resps = []
    store_names.each do |store_name|
      resps << self.activation(store_name, tinkit_store_name)
    end
    resps
  end
end


