#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../../lib/helpers/require_helper')
require Tinkit.glue 'sdb_s3/sdb_s3_files_mgr'

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

  it "4) should be well behaved adding more files" do 
    node = nil
    @attach_handler.add(node, @file_datas)


    #Get the original files and verify data
    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename])
      data = @attach_handler.get_raw_data(node, file_basename) 
      data.should == @file_stored_data[file_basename]
    end    
    
    #create some more files
    file1_data = "Example File1\nNEW!! text"
    file3_data = "Example File3\nYet more text"
    file4_data = "Example File4\nand more text"
    file3_fname = "/tmp/example_file3.txt"
    file4_fname = "/tmp/example_file4.txt"
    files = {@file1_fname => file1_data, file3_fname => file3_data, file4_fname => file4_data}
    files.each do |fname, data|
      File.open(fname, 'w'){|f| f.write(data)}
    end
    file1_data.should == File.open(@file1_fname){|f| f.read}
    @file_datas2 = [{:src_filename => @file1_fname},
                          {:src_filename => file3_fname},
                          {:src_filename => file4_fname}]
    
    #add them
    @attach_handler.add(node, @file_datas2)

    #Check the unchanged file (file2)
    file2_basename = File.basename(@file2_fname)
    data2 = @attach_handler.get_raw_data(node, file2_basename)
    data2.should == @file_stored_data[file2_basename]
    
    #Get the changed files and verify it is the new data
    file1_basename = File.basename(@file1_fname)
    data1 = @attach_handler.get_raw_data(node, file1_basename)
    data1.should == file1_data
    
    file3_basename  = File.basename(file3_fname)
    data3 = @attach_handler.get_raw_data(node, file3_basename)
    data3.should == file3_data    

    file4_basename  = File.basename(file4_fname)
    data4 = @attach_handler.get_raw_data(node, file4_basename)
    data4.should == file4_data
  end
end