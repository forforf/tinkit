#require helper for cleaner require statements
require_relative '../lib/helpers/require_helper'

require 'rspec'
require 'couchrest'

require Tinkit.config 'tinkit_config'

describe CouchRest::Database do
  before :all do
    TinkitConfig.set_config_file_location(Tinkit::DatastoreConfig)

    @stores = TinkitConfig.activate_stores( ['iris'], 'tinkit_spec_dummy')
    @couchdb = @stores['iris'].store
  end

  it "should be running and have records" do
    db_docs = nil
    db_docs = @couchdb.documents
    db_docs['total_rows'].should >= 0
  end
end
