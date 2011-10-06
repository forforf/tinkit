require 'uri'
require 'json'
require 'couchrest'

module SpecConfig
  SensitiveDataFile = "../../../sens_data/tinkit_setup_data"
  #Set up which datastores to use for testing
  #user names and passwords are stored elsewhere for security
  SensFile = File.expand_path(SensitiveDataFile)

  ##Uncomment to create the file with data
  #data = { "TinkitStore" => { "CouchDb" => { "default" => { "user" => some user, "pw" => secret pw } } } }
  #File.open(SensFile, 'w+'){|f| f.write data.to_json}
  sens_json = File.open(SensFile, 'r') {|f| f.read }
  SensInfo = JSON.parse(sens_json)

  ConfigData = {
    :TinkitStore => {
      :CouchDb => {
        :default_store => :DevDb,
        :Iris => {
          :host => "forforf.iriscouch.com",
          :name => "tinkit_spec_tests"
        },
        :DevDb => {
          #When ec2 micros can be hosted in vpcs these can be fixed addresses
          :host => "ec2-184-72-148-99.compute-1.amazonaws.com",
          :name => "tinkit_spec_tests",
          :user => SensInfo["TinkitStore"]["CouchDb"]["default"]["user"],
          :pw => SensInfo["TinkitStore"]["CouchDb"]["default"]["pw"]
        }

      }
    }
  }




  def self.drilldown(keys, data)
    next_key = keys.shift	
    if next_key
      data = data[next_key]
      drilldown(keys, data)
    else
      return data
    end
  end

  def self.get_config_data_for_module(mod)
    mod_org = mod.to_s.split("::")
    mod_syms = mod_org.map{|m| m.to_sym}
    mod_data = self.drilldown(mod_syms, ConfigData)
  end
end


#usage:  TinkitStore.build_stores
module TinkitStore
  module CouchDb
    Config = SpecConfig::ConfigData[:TinkitStore][:CouchDb]

    #Specific CouchDb Types
    db_sources = SpecConfig::ConfigData[:TinkitStore][:CouchDb]
    module Iris
      IrisData = SpecConfig.get_config_data_for_module(self)
      def self.build_store
        params = {
          :host => IrisData[:host],
          :name => IrisData[:name]
        }
        TinkitStore::CouchDb.build_couchdb params
      end
    end
    module DevDb
      DevDbData = SpecConfig.get_config_data_for_module(self)
      def self.build_store
        params = { 
          :host => DevDbData[:host],
          :name => DevDbData[:name],
          :user => DevDbData[:user],
          :pw => DevDbData[:pw]
        }
        TinkitStore::CouchDb.build_couchdb params
      end
    end

    #CouchDb Specifics
    DefaultStore = SpecConfig::ConfigData[:TinkitStore][:CouchDb][:default_store]

    def self.build_couchdb(params)
      db_path = "/" + params[:name]
      user = params[:user]
      pw = params[:pw]
      userinfo = user + ":" + pw if user && pw
      uri_params = {
        :host => params[:host],
        :port => params[:port]||5984,
        :path => db_path,
        :userinfo => userinfo
      }
      uri = URI::HTTP.build uri_params
      CouchRest.database! uri.to_s
    end

    def self.build_store(store=DefaultStore)
      store_mod = self.const_get(store)
      store_mod.build_store
    end
  end
  DefaultStoreList = [CouchDb]
  def self.build_stores(store_list=DefaultStoreList, opts={} )
    #ToDo: Test options to set specific store types
    resp = {}  #response will be a key of class name pointing to the instance
    store_list.each do |store|
      store_inst = if opts.keys.include? store
        store.build_store(opts[store])
      else
        store.build_store
      end
      store_mod_chain = store.to_s.split("::")
      store_key = store_mod_chain.last
      resp[store_key.to_s.to_sym] = store_inst
    end
    resp
  end
end

