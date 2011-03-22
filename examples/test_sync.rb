require '../lib/tinkit'  #<-- eventually will be gem 'bufs'
require 'group_delegator'

module NodeHelper
  def self.env_builder(model_name, node_class_id, user_id, path, host = nil)
        #binding data (note this occurs in two different places in the env)
    
    key_fields = {:required_keys => [:id],
                         :primary_key => :id }


    #data model
    field_op_set =nil
    #op_set_mod => <Using default definitions>
    
    data_model = {:field_op_set => field_op_set, :key_fields => key_fields, :views => nil}
    
    #persistence layer model
    pmodel_env = { :host => host,
                          :path => path,
                          :user_id => user_id}
    persist_model = {:name => model_name, :env => pmodel_env}
    
    #final env model
    env = { :node_class_id => node_class_id,
                :data_model => data_model,
                :persist_model => persist_model }
  end
end


#If you have CouchRest:
  #Lets create a couchrest instance to interface to our CouchDB
  require 'couchrest'
  example_couchdb_location = "http://127.0.0.1:5984/example/"
  #example_couchdb_location = "http://bufs.couchone.com/example"
  couchrest_instance = CouchRest.database!(example_couchdb_location)
  
  #while we're at it, lets create a filesystem store as well
  filestore_loc = "/tmp/bufs_test/"

  couch_class_id = :CouchClass
  file_class_id = :FileClass
  sdbs3_class_id = :SdbS3Class
  user_id = "Me"
  
  cr_path = couchrest_instance.uri
  cr_host = couchrest_instance.host
  
  fs_path = filestore_loc
  
  sdbs3_path = "MyDomain"
  #filesystem doesn't require host
  #building the couchrest environment
  couch_env = NodeHelper.env_builder("couchrest", couch_class_id, user_id, cr_path, cr_host)
  
  #building the filesystem environment
  filesys_env = NodeHelper.env_builder("filesystem", file_class_id, user_id, fs_path)
  #p couch_env
  
  #building an environment for AWS (Simple DB for data, S3 for attachments)
  sdbs3_env = NodeHelper.env_builder("sdb_s3", sdbs3_class_id, user_id, sdbs3_path)
  
  #Testing with Class for NodeElementOperations
  #node_ops = NewNodeElementOperations.new.data_ops
  
  #In the future you won't need seperate classes for the models.
  
  ExampleCouchClass = TinkitNodeFactory.make(couch_env)
  ExampleFileClass = TinkitNodeFactory.make(filesys_env)
  ExampleSdbS3Class = TinkitNodeFactory.make(sdbs3_env)
  a_couch_node = ExampleCouchClass.new({:id => "My_ID1", :data => "Hello World from couchrest"})
  
  
  a_file_node = ExampleFileClass.new({:id => "My_ID2", :data =>"Hello World from filesystem" })
  
  a_sdbs3_node = ExampleSdbS3Class.new({:id => "My_ID2", :data =>"Hello World from AWS Simple DB (with S3 for files)" })
  puts "Nodes in memory"
  p a_couch_node._user_data
  p a_file_node._user_data
  p a_sdbs3_node._user_data

#TESTING SYNC

  GroupDelegator.__set_source_classes([ExampleCouchClass, ExampleFileClass, ExampleSdbS3Class])
  #Add a node via sync
  a_sync_node = GroupDelegator.new({:id => "My_SyncID1", :data =>"Hello World Synced" })

  p a_sync_node._user_data.values

  a_sync_node.__save

  puts "Node in CouchDB"
  #p hello_world_node

  #get the individual ids from the sync data
  #Get the couchrest instance
  cr_objs = a_sync_node.__objs_by_class[ExampleCouchClass]
  cr_obj = cr_objs.first
  p cr_obj._model_metadata
=begin
  all_metadata =  a_sync_node._model_metadata
  all_metadata.values.each do |md|
    p md
  end
  cr_mds =  all_metadata.values.select{|md| md if md[:_id]}
  cr_md = cr_mds.first if cr_mds.size == 1
  cr_id = cr_md[:_id]
  f_mds = all_metadata.values.select{|md| md if md[:files_namespace]}
  f_md = f_mds.first if f_mds.size == 1
  f_md = f_md[:files_namespace]
  p couchrest_instance.get(cr_id)
  puts
  puts "Or you can get the couch node from the command line using curl:"
  puts "curl -X GET #{example_couchdb_location}/#{CGI.escape(cr_id)}"
  puts

  puts "The file data should be at (look for .node_data.json)"
  puts "ls -al #{File.join(f_md, "My_SyncID1")}/"
  puts "We can also add a field dynamically, for example a \"tags\" field"
  puts "Node after dynamically adding new data element"
  puts
=end
