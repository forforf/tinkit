require 'uri'
require 'json'
require 'couchrest'

module SpecConfig

  ConfigData = 




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

