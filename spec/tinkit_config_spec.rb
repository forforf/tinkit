require_relative "../lib/helpers/require_helper"
require 'fileutils'
require 'psych'

require Tinkit.config 'tinkit_config'

module TinkitConfigSpec
  SensDataLocation =  "../../../sens_data/tinkit_setup_data"

  def sample_data
    data = {
      'avail_stores' => {
        'iris' => {
          'type' => 'couchdb',
          'host' => 'foo.iriscouch.com',
          'user' => nil
        }
      }
    }
  end
end

describe "setting config file", TinkitConfig do
  include TinkitConfigSpec
  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = sample_data
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

describe "Activating Stores", TinkitConfig do
  include TinkitConfigSpec

  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = sample_data
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
    resps.first.success_flag.should == false
  end

  it "should activate couchdb store" do
    TinkitConfig.set_config_file_location SensDataLocation
    resps = TinkitConfig.activate_stores( ['iris'], 'tinkit_spec_dummy')
    resps.size.should == 1
    resps.first.success_flag.should == true
  end
end
