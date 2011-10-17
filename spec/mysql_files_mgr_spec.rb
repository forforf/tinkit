#require helper for cleaner require statements
#require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')
require_relative '../lib/helpers/require_helper'
require Tinkit.glue 'mysql/mysql_files_mgr'

include MysqlInterface
GlueEnvMock = Struct.new(:model_key, :file_mgr_table)

describe FilesMgr, "Setup and intialization" do

  before(:all) do
    
    @glue_env_mock = GlueEnvMock.new("_id", "fake_file_table_name")
    @node_key = :_id
    
    file1_data = "Example File1\nJust some text"
    file2_data = "Example File2\nJust some more text"
    file1_fname = "/tmp/example_file1.txt"
    file2_fname = "/tmp/example_file2.txt"
    files = {file1_fname => file1_data, file2_fname => file2_data}
    files.each do |fname, data|
      File.open(fname, 'w'){|f| f.write(data)}
    end
    @file_datas = [{:src_filename => @file1_fname}, {:src_filename => file2_fname}]
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
  end
  
  it "should initialize" do
    
    #we're not creating the table yet, as that depends on the glue and user
    node_key_value = @node1_data[@node_key]
    attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    
    #note actual table is setup in glue_env, not file_mgr
    attach_handler.file_table_name.should == @glue_env_mock.file_mgr_table
  end
end
  
describe FilesMgr, "Basic Operations" do
  before(:all) do
    @file_table_name = "attachment_spec__node_loc"
    @file1_fname = "/tmp/example_file1.txt"
    @file2_fname = "/tmp/example_file2.txt"
    f1_bname = File.basename(@file1_fname)
    f2_bname = File.basename(@file2_fname)
    @file_stored_data = { f1_bname => File.open(@file1_fname, 'rb'){|f| f.read},
                      f2_bname =>File.open(@file2_fname, 'rb'){|f| f.read} }
                      
    @mock_key = :_id
    @nodeMockClass = Struct.new(@mock_key, :my_GlueEnv)
    
    @glue_env_mock = GlueEnvMock.new(@mock_key.to_s,
                                                   @file_table_name)

    #set up table for spec
    
    primary_key = '__pkid-file'
    home_dir = ENV["HOME"]  
    my_pw = File.open("#{home_dir}/.locker/tinkit_mysql"){|f| f.read}.strip
    @dbh = DBI.connect("DBI:Mysql:tinkit:localhost", "tinkit", my_pw)
    
    sql = "CREATE TABLE IF NOT EXISTS `#{@file_table_name}` (
          `#{primary_key}` INT NOT NULL AUTO_INCREMENT,
          node_name VARCHAR(255),
          basename VARCHAR(255) NOT NULL,
          content_type VARCHAR(255),
          modified_at VARCHAR(255),
          raw_content LONGBLOB,
          PRIMARY KEY (`#{primary_key}`),
          UNIQUE KEY (node_name, basename) )"
     @dbh.do(sql)    
    #
    @file_datas = [{:src_filename => @file1_fname}, {:src_filename => @file2_fname}]
  end
  
  
  before(:each) do
    @node1_data = {:_id => 'spec_test1', :data => 'stuff1'}
    @node_mock = @nodeMockClass.new(@node1_data[@mock_key], 
                                                        @glue_env_mock)
    
    node_key_value = @node1_data[@node_key]
    @attach_handler = FilesMgr.new(@glue_env_mock, node_key_value)
    #@attach_handler.subtract_files(nil, :all)
  end
  
  after(:all) do
    sql = "DROP TABLE `#{@file_table_name}`"
    @dbh.do(sql)
  end
  
  it "should add and retrieve files" do
    node = @node_mock

    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename])
      data = @attach_handler.get_raw_data(node, file_basename) 
      data.should be_nil
    end
      
    #Add the Files  
    @attach_handler.add(node, @file_datas)
    
    #Get the files and verify data
    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename])
      data = @attach_handler.get_raw_data(node, file_basename) 
      data.should == @file_stored_data[file_basename]
    end
  end

  it "should list attachment files" do
    files = @attach_handler.list(@node_mock)
    files.sort.should == @file_stored_data.keys.sort
  end

  it "should list metadata" do
    
    md = @attach_handler.get_attachments_metadata(@node_mock)
    md.should_not == nil
    @file_datas.each do |file_data|
      file_basename = File.basename(file_data[:src_filename]) 
      each_md = md[file_basename]
      each_md.should_not == nil
      each_md.keys.should include :content_type
      each_md.keys.should include :file_modified
      
      file_basename = File.basename(file_data[:src_filename])
      md[file_basename][:content_type].should =~ /^text\/plain/
      time_str = md[file_basename][:file_modified]
      Time.parse(time_str).should > Time.now - 1 #should have been modified less than a second ago
    end
  end
  
  it "should be well behaved adding more files" do 
    node = @node_mock

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
  
  it "should delete (subtract) files" do
    node = @node_mock
    files_to_delete = [@file1_fname, @file2_fname]
    #they should exist in the node
    files_to_delete.each do |fname|
      file_basename = File.basename(fname)
      data = @attach_handler.get_raw_data(node, file_basename)
      data.should match /^Example File/
    end
    
    basenames_to_delete = files_to_delete.map{|f| File.basename(f)}
    @attach_handler.subtract(node, basenames_to_delete)
    
    files_to_delete.each do |fname|
      file_basename = File.basename(fname)
      data = @attach_handler.get_raw_data(node, file_basename)
      data.should be_nil
    end    
  end  
  
  it "should add attachments from the raw data" do
    node = @node_mock

    raw_data = "Example File3\nYet more text"
    content_type = "text/plain"
    modified_at = Time.now.to_s
    att_name = "example_raw_data.txt"
    
    #Add the Raw Data
    @attach_handler.add_raw_data(node, att_name, content_type, raw_data, modified_at)
    
    #Get the files and verify data

    data = @attach_handler.get_raw_data(node, att_name) 
    md = @attach_handler.get_attachments_metadata(node)[att_name]
      
    data.should == raw_data
    md[:content_type].should == content_type
    md[:file_modified].should == modified_at
  end
  
  it "should delete all (subtract_all) files" do
    node = @node_mock
    
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
