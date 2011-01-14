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
    node_key_value = @node1_data[@node_key]
    kill_attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    kill_attach_handler.destroy_file_container
  end

  it "7) should add attachments from the raw data" do
    node = nil
    @attach_handler.add(node, @file_datas)
    
    raw_data = "Example File3\nYet more text"
    content_type = "text/plain"
    modified_at = Time.now.to_s
    att_name = "example_raw_data.txt"
    
    #Add the Raw Data
    @attach_handler.add_raw_data(node, att_name, content_type, raw_data, modified_at)
    
    #Get the files and verify data
    
    #Let's try killing the @attach_handler  [Fixed It!]
    @attach_handler = nil
    
    node_key_value = @node1_data[@node_key]
    new_attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)

    data = new_attach_handler.get_raw_data(node, att_name) 
    all_metadata = new_attach_handler.get_attachments_metadata(node)
    all_metadata.should_not be_nil

    attachment_metadata = all_metadata[att_name]
      
    data.should == raw_data
    
    #THESE TESTS FAIL (now pass, the attach handler must be reinitialized to work)
    #TODO: There is a metadata issue here, but not in general
    #something strange about metadata being requested like this
    #it might have to do with the retries?
    attachment_metadata.should_not be_nil
    att_md = attachment_metadata
    att_md[:content_type].should == content_type
    Time.parse(att_md[:file_modified]).should == Time.parse(modified_at)
  end
end