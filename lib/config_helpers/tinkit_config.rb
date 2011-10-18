require 'uri'
require 'couchrest'
require 'mysql'
require 'dbi'
require 'json'
require 'fileutils'

require_relative 'sens_data'

module Tinkit
  DatastoreConfig = File.join(File.dirname(__FILE__), "../../../../sens_data/tinkit_setup_data")
end

module TinkitConfig
  @@config_file_location = nil
  
  TinkitTypeToMethod = {
    'couchdb' => {
      :method => :activate_couch,
      :args => ['host','user']
    },
    'file' => {
      :method => :activate_file,
      :args => ['host']
    },
    'mysql' => {
      :method => :activate_mysql,
      :args => ['host', 'user']
    }
  }

  class StoreAccess
    #Admin = 8
    Read, Write, Reachable, Exists = 8,4,2,1
    attr_reader :reach, :read, :write, :exists
    def initialize(init_perms={})
      reset
      perm_keys = init_perms.delete_if{|k,v| !v }
      perms = perm_keys.keys
      add_permissions(perms)
    end

    def reset
      @reach, @read, @write, @exists = 0,0,0,0
    end
    
    def permissions
      @read + @write + @reach + @exists || 0
    end

    def add_permissions(perm_list)
      perm_list = *perm_list
      @read = Read if  perm_list.include? :read
      @write = Write if perm_list.include? :write
      @reach = Reachable if perm_list.include? :reach
      @exists = Exists if perm_list.include? :exists
      get_permissions
    end

    def get_permissions
      perm_val = permissions
      raise "Invalid Permission data" if perm_val > 15
      result = []
      result << :read if  (perm_val/8) % 2 == 1
      result << :write if (perm_val/4) % 2 == 1
      result << :reach if (perm_val/2) % 2 == 1
      result << :exists if perm_val    % 2 == 1 
      result << :none if   perm_val == 0
      result
    end
  end

  class Store
    attr_reader :access, :loc
    #TODO: Temporary fix for Mysql
    attr_accessor :mysql_connection

    def initialize(loc, access)
      @loc = loc
      @access =  access
    end
  end

  class Resp
    attr_reader :success_flag, :type, :native
    attr_accessor :store

    def initialize(type, native)
      @type = type
      @native = native
      @success_flag = parse_resp(type, native)
      @store = nil
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
       when 'file'
       
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
    #host = "forforf.iriscouch.com"
    url = URI::HTTP.build :userinfo => userinfo, :host => host, :path => db_path, :port => 5984
    store = CouchRest.database! url.to_s
    #check if store exists
    resp_ex = JSON.parse(`curl -sX GET #{url.to_s}`)
    store_caps = StoreAccess.new
    store_caps.add_permissions([:exists, :reach, :read]) if resp_ex["db_name"] == db_name
    dummy_data = {:dummy => "Dummy"}.to_json
    #check if store can be written to (and read)
    resp_rw = JSON.parse(`curl -sX POST #{url.to_s} -H 'Content-Type:application/json' -d \'#{dummy_data}\'`)
    store_caps.add_permissions([:write]) if resp_rw["id"]
    #resp = Resp.new('couchdb', native_resp_json)
    #resp.store = store
    #return store_caps
    Store.new(store, store_caps)
  end

  #Change database to generic test database, rather than spec database
  def self.activate_mysql(args)
    mysql_db_name = args[:store_name]
    host = args[:host]
    userinfo = args[:user]
    user, pw = userinfo.split ":"
    dbi_host = "DBI:Mysql:#{mysql_db_name}:#{host}"
    store_caps = StoreAccess.new
    store = nil
    begin
      store = DBI.connect dbi_host, user, pw
      row = store.select_one("SELECT VERSION()")
      store_caps.add_permissions([:exists, :reach, :read]) if row[0].to_f > 5.0
      store.do "DROP TABLE IF EXISTS dummy"
      store.do "CREATE TABLE dummy (
                  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                  test_data CHAR(20) NOT NULL,
                  PRIMARY KEY (id))"
      rows = store.do "INSERT INTO dummy(test_data)
                         VALUES
                           ('Test1'), ('Test2')"
      store_caps.add_permissions([:write]) if rows > 1
      store.do "DROP TABLE IF EXISTS dummy"
    
      #puts "Server version: " + row[0]
    rescue DBI::DatabaseError => e
      store_caps.reset
      #p e.exception
      #p e.message 
    ensure
      store.disconnect if store
    end
    store_obj = Store.new(store, store_caps)
    store_obj.mysql_connection = [dbi_host, user, pw]
    store_obj
  end

  def self.activate_file(args)
    file_store_name = args[:store_name]
    file_store_dir = args[:host]
    store_caps = StoreAccess.new
    file_store_path = File.join(file_store_dir, file_store_name)
    begin
      native_resp = FileUtils.mkdir_p(file_store_path)
      store_caps.add_permissions([:exists, :reach]) if native_resp == [ file_store_path]
    rescue Errno::EACCES
      #no permissions
    end
    store_caps.add_permissions([:write]) if File.writable?(file_store_path)
    store_caps.add_permissions([:read]) if File.readable?(file_store_path)
    #return store_caps
    Store.new(file_store_path, store_caps)
  end


  def self.activate_stores(store_names, tinkit_store_name)
    raise "Configuration file location not set. Use:  #{self.name}.set_config_file_location(\"path/to/config/file\")" unless @@config_file_location
    store_info = {}
    store_names.each do |store_name|
      store_info[store_name] =  self.activation(store_name, tinkit_store_name)
    end
    store_info
  end
end


