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
        }
      }
    }
  end
end

describe "TinkitConfig::StoreCapabilities" do
  before :each do
    @cap = TinkitConfig::StoreCapabilities.new
  end

  it "should initialize properly" do
    Caps = TinkitConfig::StoreCapabilities
    Caps.new.is_a?(TinkitConfig::StoreCapabilities).should == true
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
    resps = TinkitConfig.activate_stores(['iris'], 'some_db_name')
    resps.size.should == 1
    resps['iris'].get_permissions.should == [:none]
  end

  it "should activate couchdb store" do
    TinkitConfig.set_config_file_location SensDataLocation
    store_capabilities = TinkitConfig.activate_stores( ['iris'], 'tinkit_spec_dummy')
    store_capabilities.size.should == 1
    [:read, :write, :exists, :reach].each do |perm|
      store_capabilities['iris'].get_permissions.should include perm
    end
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

  it "should provide informative response if file cant be createdd" do
    store_capabilities = TinkitConfig.activate_stores(['tmp_files'], 'some_file_name')
    store_capabilities.size.should == 1
    store_capabilities['tmp_files'].get_permissions.should == [:none]
  end

  it "should activate file store" do
    TinkitConfig.set_config_file_location SensDataLocation
    store_capabilities = TinkitConfig.activate_stores( ['tmp_files'], 'tinkit_spec_dummy')
    [:read, :write, :exists, :reach].each do |perm|
      store_capabilities['tmp_files'].get_permissions.should include perm
    end
  end
end
