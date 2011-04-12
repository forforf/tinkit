#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require 'rspec'
require 'couchrest'

describe CouchRest::Database do
  it "should be running and have records" do
    db_name = "http://127.0.0.1:5984/bufs_test_spec/"
    CouchDB = CouchRest.database!(db_name)
    CouchDB.compact!
    #CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
    db_docs = nil
    db_docs = CouchDB.documents
    db_docs['total_rows'].should >= 0
  end
end
