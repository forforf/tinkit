#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../../lib/helpers/require_helper')
require Bufs.glue 'sdb_s3/sdb_s3_files_mgr'

include SdbS3Interface
GlueEnvMock = Struct.new(:user_datastore_location)

describe FilesMgr, "Setup and intialization" do
  before(:all) do

    @glue_env_mock = GlueEnvMock.new("attachment_spec__node_loc")
    @node_key = :_id
    
    file1_data = "Example File1\nJust some text"
    file2_data = "Example File2\nJust some more text"
    file1_fname = "/tmp/example_file1.txt"
    file2_fname = "/tmp/example_file2.txt"
    files = {file1_fname => file1_data, file2_fname => file2_data}
    files.each do |fname, data|
      File.open(fname, 'w'){|f| f.write(data)}
    end
    @file_datas = [{:src_filename => file1_fname}, {:src_filename => file2_fname}]
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
  end
  
  it "should initialize" do
    node_key_value = @node1_data[@node_key]
    attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    buck_prefix = FilesMgr::BucketNamespacePrefix
    node_loc = @glue_env_mock.user_datastore_location
    check_bucket_location = "#{buck_prefix}_#{node_loc}"
    #the below will sometimes fail due to AWS
    attach_handler.bucket_name.should == check_bucket_location
  end
end

describe FilesMgr, "Basic Operations" do
  before(:all) do
    @file1_fname = "/tmp/example_file1.txt"
    @file2_fname = "/tmp/example_file2.txt"
    f1_bname = File.basename(@file1_fname)
    f2_bname = File.basename(@file2_fname)
    @file_stored_data = { f1_bname => File.open(@file1_fname, 'rb'){|f| f.read},
                      f2_bname =>File.open(@file2_fname, 'rb'){|f| f.read} }
    @glue_env_mock = GlueEnvMock.new("attachment_spec__node_loc")
    @node_key = :_id
    @file_datas = [{:src_filename => @file1_fname}, {:src_filename => @file2_fname}]
  end
  
  
  before(:each) do
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
    node_key_value = @node1_data[@node_key]
    @attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    @attach_handler.subtract_files(nil, :all)
  end
  
  after(:each) do
    @attach_handler.destroy_file_container
  end

  it "8) should delete all (subtract_all) files" do
    node = nil
    @attach_handler.add(node, @file_datas)
    
    #create some more attachments
    del_data = {}
    del_data["del_data1"] = "my life will be short"
    del_data["del_data2"] = "alas too short"
    
    #add the attachments
    del_data.each do |name, data|
      @attach_handler.add_raw_data(node, name, "text/plain", data, Time.now.to_s)
    end
    
    #verify it's there
    del_data.each do |name, data|
      stored_data = @attach_handler.get_raw_data(node, name)
      stored_data.should == data
    end

    #delete it all
    @attach_handler.subtract(node, :all)
    
    #verify it's not  there

    del_data.each do |name, data|
      stored_data = @attach_handler.get_raw_data(node, name)
      stored_data.should be_nil
    end
  end
end