#require helper for cleaner require statements
require_relative '../lib/helpers/require_helper'

require 'rspec'
require 'couchrest'

require Tinkit.config 'tinkit_config'

describe CouchRest::Database do
  before :all do
    TinkitConfig.set_config_file_location(Tinkit::DatastoreConfig)
    @couch_stores = ['iris','dev_couch'] 

    @stores = TinkitConfig.activate_stores( @couch_stores, 'tinkit_spec_dummy')
    locs = {}
    @couch_stores.each do |store|
     locs[store] = @stores[store].loc
    end
    @couchdb_locs = locs
  end

  it "should be running and have records" do
    @couch_stores.each do |store|
      couchdb = @couchdb_locs[store]
      db_docs = nil
      db_docs = couchdb.documents
      db_docs['total_rows'].should >= 0
      puts "Running: #{store}: #{ couchdb}"
    end
  end
end
