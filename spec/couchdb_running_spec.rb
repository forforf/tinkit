#require helper for cleaner require statements
require_relative '../lib/helpers/require_helper'

require 'rspec'
require 'couchrest'

require_relative 'spec_config'

describe CouchRest::Database do
  before :all do
    @stores = TinkitStore.build_stores
    @couchdb = @stores[:CouchDb]
  end

  it "should be running and have records" do
    db_docs = nil
    db_docs = @couchdb.documents
    db_docs['total_rows'].should >= 0
  end
end
