require_relative "../lib/helpers/require_helper"
require 'fileutils'
require 'psych'

require Tinkit.config 'tinkit_config'

module TinkitConfigSpec
  SensDataLocation =  Tinkit::DatastoreConfig 

  def invalid_store_data
    data = {
      'avail_stores' => {
        'iris' => {
          'type' => 'couchdb',
          'host' => 'foo.iriscouch.com',
          'user' => nil
        },
        'tmp_files' => {
          'type' => 'file',
          'host' => '/foo/delete_me',
          'user' => nil
        },
        'dev_mysql' => {
          'type' => 'mysql',
          'host' => 'foo.somewhere.com',
          'user' => 'nobody:nobody'
        },
        'dev_sdb_s3' => {
          'type' => 'sdb_s3',
          'host' => nil,
          'user' => 'foo:bar'
        }
      }
    }
  end
end

describe "TinkitConfig::StoreAccess" do
  before :each do
    @cap = TinkitConfig::StoreAccess.new
  end

  it "should initialize properly" do
    Caps = TinkitConfig::StoreAccess
    Caps.new.is_a?(TinkitConfig::StoreAccess).should == true
    Caps.new.permissions.should == 0
    Caps.new(:exists => true).permissions.should == 1
    Caps.new(:reach => true).permissions.should == 2
    Caps.new(:write => true).permissions.should == 4
    Caps.new(:read => true).permissions.should == 8
    all_perms = {:exists => true, :reach => true, :write => true, :read => true}
    Caps.new(all_perms).permissions.should == 15
  end

  it "should set permissions after initialization" do
    @cap.add_permissions(:exists)
    @cap.permissions.should == 1
    @cap.add_permissions(:reach)
    @cap.permissions.should == 3
    @cap.add_permissions(:write)
    @cap.permissions.should == 7
    @cap.add_permissions(:read)
    @cap.permissions.should == 15
  end

  #Doesn't test all possibilities, just the basics
  it "should get human readable permissions" do
    @cap.get_permissions.should == [:none]
    all_perms = [:read, :write, :reach, :exists]
    @cap.add_permissions(all_perms)
    all_perms.each do |perm|
      @cap.get_permissions.should include perm
    end
  end 
end

describe "setting config file", TinkitConfig do
  include TinkitConfigSpec
  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = invalid_store_data
    yaml = Psych.dump @data 
    File.open(@tmp_file,'w+'){|f| f.write(yaml)}
  end

  after :each do
    FileUtils.rm @tmp_file if File.exist? @tmp_file
  end
   
  it "should raise error if config file doesnt exist" do
    expect{TinkitConfig.set_config_file_location("/road/to/nowhere")}.to raise_error(IOError)
  end

  it "should work with a valid file location" do
    FileUtils.touch(@tmp_file)
    TinkitConfig.set_config_file_location(@tmp_file).should == @tmp_file
  end
end

describe "Activating CouchDb Stores", TinkitConfig do
  include TinkitConfigSpec

  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = invalid_store_data
    yaml = Psych.dump @data
    File.open(@tmp_file,'w+'){|f| f.write(yaml)}
    TinkitConfig.set_config_file_location(@tmp_file)
  end

  after :each do
    FileUtils.rm @tmp_file if File.exist? @tmp_file
  end

  it "should fail if store isnt in config" do
    expect{TinkitConfig.activate_stores( ['foo'], 'db_name')}.to raise_error NameError
  end

  it "should provide informative response if db doesnt exist" do
    stores = TinkitConfig.activate_stores(['iris'], 'invalid_db_name')
    stores.size.should == 1
    stores['iris'].access.get_permissions.should == [:none]
  end

  it "should activate couchdb store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['iris'], 'tinkit_spec_dummy')
    stores.size.should == 1
    [:read, :write, :exists, :reach].each do |perm|
      stores['iris'].access.get_permissions.should include perm
    end
  end

  it "should return a reference location to the store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['iris'], 'tinkit_spec_dummy')
    stores['iris'].loc.class.should == CouchRest::Database
    stores['iris'].loc.to_s.should == "http://forforf.iriscouch.com:5984/tinkit_spec_dummy"
  end


end

describe "Activating File Stores", TinkitConfig do
  include TinkitConfigSpec

  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = invalid_store_data
    yaml = Psych.dump @data
    File.open(@tmp_file,'w+'){|f| f.write(yaml)}
    TinkitConfig.set_config_file_location(@tmp_file)
  end

  it "should provide informative response if file cant be created" do
    stores = TinkitConfig.activate_stores(['tmp_files'], 'invalid_file_name')
    stores.size.should == 1
    stores['tmp_files'].access.get_permissions.should == [:none]
  end

  it "should activate file store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['tmp_files'], 'tinkit_spec_dummy')
    [:read, :write, :exists, :reach].each do |perm|
      stores['tmp_files'].access.get_permissions.should include perm
    end
  end

  it "should return a reference location to the store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['tmp_files'], 'tinkit_spec_dummy')
    stores['tmp_files'].loc.should == "/tmp/tinkit_test_data/tinkit_spec_dummy"
  end
end

describe "Acitvating Mysql Stores", TinkitConfig do
  include TinkitConfigSpec
  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = invalid_store_data
    yaml = Psych.dump @data
    File.open(@tmp_file,'w+'){|f| f.write(yaml)}
    TinkitConfig.set_config_file_location(@tmp_file)
  end

  it "should provide informative response if mysql db cant be created" do
    stores = TinkitConfig.activate_stores(['dev_mysql'], 'invalid_db_name')
    stores.size.should == 1
    stores['dev_mysql'].access.get_permissions.should == [:none]
  end

  it "should activate mysql store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['dev_mysql'], 'tinkit_spec_dummy')
    [:read, :write, :exists, :reach].each do |perm|
        stores['dev_mysql'].access.get_permissions
      stores['dev_mysql'].access.get_permissions.should include perm
    end
  end

  it "should return a reference location to the store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['dev_mysql'], 'tinkit_spec_dummy')
    stores['dev_mysql'].loc.class.should == DBI::DatabaseHandle
    stores['dev_mysql'].loc.driver_name.should == "Mysql"
  end

end

#TODO: Include S3
describe "Acitvating SDB S3 Stores", TinkitConfig do
  include TinkitConfigSpec
  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = invalid_store_data
    yaml = Psych.dump @data
    File.open(@tmp_file,'w+'){|f| f.write(yaml)}
    TinkitConfig.set_config_file_location(@tmp_file)
  end

  it "should provide informative response if mysql db cant be created" do
    stores = TinkitConfig.activate_stores(['dev_sdb_s3'], 'invalid_db_name')
    stores.size.should == 1
    stores['dev_sdb_s3'].access.get_permissions.should == [:none]
  end

  it "should activate sdb store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['dev_sdb_s3'], 'tinkit_spec_dummy')
    [:read, :write, :exists, :reach].each do |perm|
        stores['dev_sdb_s3'].access.get_permissions
      stores['dev_sdb_s3'].access.get_permissions.should include perm
    end
  end

  it "should return a reference location to the store" do
    TinkitConfig.set_config_file_location SensDataLocation
    stores = TinkitConfig.activate_stores( ['dev_sdb_s3'], 'tinkit_spec_dummy')
    stores['dev_sdb_s3'].loc.class.should == AwsSdb::Service
    stores['dev_sdb_s3'].loc.list_domains.first.should include 'tinkit_spec_dummy'
  end

end
