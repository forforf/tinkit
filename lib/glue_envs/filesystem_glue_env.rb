#Tinkit directory organization defined in lib/helpers/require_helper.rb
require Tinkit.midas 'bufs_data_structure'
require Tinkit.glue 'filesystem/filesystem_files_mgr'
require Tinkit.helpers 'hash_helpers'

#class ViewsMgr
module TinkitFileSystemViews
  #Set Logger
  @@log = TinkitLog.set(self.name, :warn)

  #Dependency on TinkitInfoDocEnvMethods
  attr_accessor :model_actor


  #def initialize(model_actor=nil)
  #  @model_actor = model_actor #provides the model actor that can provide views
  #  @data_file = model_actor[:data_file]
  #end
  

  #TODO create an index to speed queries? sync issues?
  def self.by_my_category(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    #raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    match_keys = [match_keys].flatten
    my_dir = user_datastore_location
    bfss = nil
    match_keys.each do |match_key|
      my_cat_dir = match_key
      wkg_dir = File.join(my_dir, my_cat_dir)
      if File.exists?(wkg_dir)
	bfss = bfss || []
	data_file_path = File.join(wkg_dir, data_file)
	node_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	#bfs = self.new(node_data)
	bfss << node_data #bfs
      end
      #return bfss   #returned as an array for compatibility with other search and node types
    #else
    #  puts "Warning: #{wkg_dir.inspect} was not found"
    #  return nil
    end
    return bfss
  end

  def self.by_parent_categories(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    match_keys = [match_keys].flatten
    #all_nodes = all collection method when all is moved into here
    matching_node_data = []
    all_wkg_entries = Dir.working_entries(user_datastore_location)
    all_wkg_entries.each do |entry|
      wkg_dir = File.join(user_datastore_location, entry)
      if File.exists?(wkg_dir)
	      data_file_path = File.join(wkg_dir, data_file)
	      json_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	      node_data = HashKeys.str_to_sym(json_data)
	        match_keys.each do |k|
	        pc = node_data[:parent_categories]
	        if pc && pc.include?(k)
	          matching_node_data << node_data
	          break  #we don't need to loop through each parent cat, if one already matches
	        end
        end
      end
    end
    #we now have all mathcing data
    return matching_node_data
  end
end 

module FilesystemViews

  def call_view(field_name, moab_data, namespace_key, user_datastore_location, match_key, view_name = nil)
    data_file = moab_data[:moab_datastore_name]
    matching_records = []
    all_file_records = Dir.working_entries(user_datastore_location)
    all_file_records.each do |file_record|
      record_path = File.join(user_datastore_location, file_record)
      if File.exists?(record_path)
        data_file_path = File.join(record_path, data_file)
        json_data = JSON.parse(File.open(data_file_path){|f| f.read})
        record = HashKeys.str_to_sym(json_data)
        field_data = record[field_name]
        if field_data == match_key
          matching_records << record
        end
      end
    end
    matching_records
  end

  def self.by_my_category(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    #raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    match_keys = [match_keys].flatten
    my_dir = user_datastore_location
    bfss = nil
    match_keys.each do |match_key|
      my_cat_dir = match_key
      wkg_dir = File.join(my_dir, my_cat_dir)
      if File.exists?(wkg_dir)
	bfss = bfss || []
	data_file_path = File.join(wkg_dir, data_file)
	node_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	#bfs = self.new(node_data)
	bfss << node_data #bfs
      end
      #return bfss   #returned as an array for compatibility with other search and node types
    #else
    #  puts "Warning: #{wkg_dir.inspect} was not found"
    #  return nil
    end
    return bfss
  end
end


module FilesystemEnv
  #EnvName = :filesystem_env
  BADCHARS = /:/  #there's a lot more
  
class GlueEnv
  #This class provides a generic persistence layer interface to the
  #outside world that maps to the specific implementations of the
  #underlying persistent layers
  #Set Logger
  @@log = TinkitLog.set(self.name, :warn)
  
  include FilesystemViews
  
  PersistLayerKey = :node_path # is the full path including node_key transform
  #see mysql_glue_env to decouple persistent layer key from node key
  VersionKey = :_rev #to have timestamp
  NamespaceKey = :files_namespace
  
  #FileSystemMetadataKeys = [PersistLayerKey]
  
  MoabDataStoreDir = ".model"
  MoabDatastoreName = ".node_data.json"
  
  #include FileSystemEnv

#TODO: Rather than using File class directly, should a special class be used?
attr_accessor :user_id,
           :user_datastore_location,
			     :metadata_keys,
			     :required_instance_keys,
			     :required_save_keys,
			     :node_key,
			     :model_key,
			     :version_key,
			     :namespace_key,
			     :_files_mgr_class,
           :views,
			     :model_save_params,
           :moab_data,
           :persist_layer_key,
           #accessors specific to this persitence model
            :moab_datastore_name
            
            
  def initialize(persist_env, data_model_bindings)
    #TODO: determine if class_name is needed to segment cluster data within user data
    
    #via environmental settings
    filesystem_env = persist_env[:env]
    #key_fields = persist_env[:key_fields]
    fs_path = filesystem_env[:path]
    @user_id = filesystem_env[:user_id]
    @cluster_name = persist_env[:name]
    
    #data_model_bindings from NodeElementOperations
    key_fields = data_model_bindings[:key_fields] 
    initial_views_data = data_model_bindings[:views]
    
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Tinkit::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Tinkit::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Tinkit::NodeKey
  

    @moab_datastore_name = MoabDatastoreName
    @version_key = VersionKey  #
    @model_key = @node_key #ModelKey
    
    #Change model key to persiste layer key ...
    #TODO: See about not making the filesystem dependent upon the node key
    @persist_layer_key = PersistLayerKey
    
    @namespace_key = NamespaceKey
    @metadata_keys = [@persist_layer_key, @version_key, @namespace_key ] #@persist_layer_key, @namespace_key] 
    @user_datastore_location = File.join(fs_path, @user_id, MoabDataStoreDir)    
    
    
    
    @model_save_params = {:nodes_save_path => @user_datastore_location, :data_file => @moab_datastore_name, :node_key => @node_key}
    @_files_mgr_class = FilesystemInterface::FilesMgr
    @views = TinkitFileSystemViews
    @moab_data = {:moab_datastore_name => @moab_datastore_name}
    #@views_mgr = ViewsMgr.new({:data_file => @data_file_name})
    
    FileUtils.mkdir_p(fs_path) unless File.exists?(fs_path)
  end

  def query_all  #TODO move to ViewsMgr
    unless File.exists?(@user_datastore_location)
      @@log.debug {"Warning: Can't query records. The File System Directory to work from does not exist: #{@user_datastore_location}"} if @@log.debug?
    end
    all_records = []
    my_dir = @user_datastore_location + '/' #TODO: Can this be removed?
    all_entries = Dir.working_entries(my_dir) || []
    @@log.debug "querying directory: #{my_dir.inspect} and got entries: #{all_entries.inspect}"
    all_entries.each do|entry|
      all_records << get(entry) || {}
    end
    @@log.debug {"query_all returning: #{all_records.inspect}" } if @@log.debug?
    return all_records
  end
      
  #TODO: reconcile raw_all with query_all, this is the only glue env using raw_all
  def raw_all
    query_all
=begin  
    @@log.debug {"Getting All (Raw) Data using "\
                         "data loc: #{@user_datastore_location.inspect} "\
                         "datastore name: #{@moab_datastore_name.inspect}" } if @@log.debug?
    entries = query_all
    raw_nodes = []
    entries.each do |record|
      data_path = File.join(record[@persist_layer_key], @moab_datastore_name)
      data_json = File.open(data_path, 'r'){|f| f.read}
      data = JSON.parse(data_json)
      raw_nodes << data
    end
    raw_nodes
=end
  end
    #current relations supported:
  # - :equals (data in the key field matches this_value)
  # - :contains (this_value is contained in the key field data (same as equals for non-enumerable types )
  def find_nodes_where(key, relation, this_value)
    res = case relation
      when :equals
        find_equals(key, this_value)
      when :contains
        find_contains(key, this_value)
    end #case
    return res    
  end
  
  def find_equals(key, this_value) 
    results =[]
    query_all.each do |record|
      test_val = record[key]
      results << record  if test_val == this_value
    end
    results
  end
  
  def find_contains(key, this_value) 
    results =[]
    query_all.each do |record|
      test_val = record[key]
      results << record  if find_contains_type_helper(test_val, this_value)
    end
    results 
  end  

  def find_contains_type_helper(stored_data, this_value)
    #p stored_dataj
    resp = nil
    #stored_data = jparse(stored_dataj)
    if stored_data.respond_to?(:"include?")
      resp = (stored_data.include?(this_value))
    else
      resp = (stored_data == this_value)
    end
    return resp
  end

  def get(id)
   return nil unless id
    #maybe put in some validations to ensure its from the proper collection namespace?
    #id may be the entry or the full path
    id_path = if id.include? (@user_datastore_location)
      id
    else
      convert_node_value_to_file_value(id)
    end
    #id_path = id #convert_node_value_to_file_value(id)
    data_file_path = File.join(id_path, @moab_datastore_name)
    rtn = if File.exists?(data_file_path)
      #data_file_path = File.join(id_path, @moab_datastore_name)
      json_data = File.open(data_file_path, 'r'){|f| f.read}
      node_data = JSON.parse(json_data)
      node_data = HashKeys.str_to_sym(node_data)
    else
      puts "Warning: File path doesn't exist: #{data_file_path.inspect}"
      []
    end
  end

  def save(new_data)
    save_data = nil
    if new_data[@persist_layer_key]
      save_data = new_data
    elsif new_data[@node_key]
      persist_key_value = convert_node_value_to_file_value(new_data[@node_key])
      save_data = new_data.merge({@persist_layer_key => persist_key_value})
    else
      raise "Save Data did not include any keys for saving, data: #{new_data.inspect}"
    end
    save_path = @user_datastore_location
    save_location = save_data[@persist_layer_key]
    @@log.debug {"Save Directory: #{save_location.inspect}"} if @@log.debug?
    #was in FileSystemEnv mixin
    #fs_save(@model_save_params, model_data)
    #puts "FSG save udl: #{@user_datastore_location.inspect}"
      #parent_path = @user_datastore_location
      #node_key = @model_save_params[:node_key]
      #node_key = @node_key
      #puts "parent_path: #{parent_path.inspect}"
      #puts "new data node key: #{new_data[node_key].inspect}"
      #node_path = File.join(parent_path, new_data[node_key])
      file_name = File.basename(@moab_datastore_name)
      file_location = File.join(save_location, file_name) 
      
      #error_str = "Filesystem can't handle some characters in/
         #{file_location.inspect}"
      #raise error_str if new_data [node_key] =~ /::/ #FilesystemEnv::BADCHARS
      @@log.info {"File Location: #{file_location.inspect}"} if @@log.info?
      model_data = HashKeys.sym_to_str(save_data)
      
      FileUtils.mkdir_p(save_location) unless File.exist?(save_location)
      #raise "WTF?" unless File.exist?(save_location)
      rev = Time.now.hash #<- I would use File.mtime, but how to get the mod time before saving?
      model_data[@version_key] = rev
      f = File.open(file_location, 'w')
      f.write(model_data.to_json)
      f.close
      model_data['rev'] = model_data[@version_key] #TODO <-Investigate to see if it could be consistent
      return model_data
  end

  def destroy_node(model_metadata)
    #root_dir = @user_datastore_location
    #model_path(model_metadata[@model_key])
    node_id = model_metadata[@persist_layer_key] || generate_model_key(nil, model_metadata[@node_key])
    
    node_dir = node_id #File.join(root_dir, node_id)
    
    FileUtils.rm_rf(node_dir)
    #node = nil
  end
  
    #namespace is used to distinguish between unique
    #data sets (i.e., users) within the model
  def generate_model_key(namespace, node_key_value)
    #was in FileSystemEnv mixin
    #fs_generate_model_key(namespace, node_key)
    #TODO: Make sure namespace is portable across model migrations
    file_name = convert_node_value_to_file_value(node_key_value)
    #TODO: Expand bad character set
    #FIXME namespace is redundant so removed it
    #"#{namespace}/#{node_key}"
    file_name
  end
  
  def model_path(model_key_value)
    #model_key_value.gsub("::","/")
  end

  def destroy_bulk(list_of_native_records)
    @@log.info {"Bulk Destroy: #{list_of_native_records.inspect}"} if @@log.info?
    return [] unless (list_of_native_records)
    list_of_native_records.each do |recs|
      next unless (recs && recs.size > 0)#raise "recs not hash: #{recs}" unless recs.class == Hash
      rec_id = recs[@persist_layer_key] || generate_model_key(nil, recs[@node_key])
      #rec_id = File.join(@user_datastore_location, rec_id) if File.dirname(rec_id) == "."
      #puts "Removing: #{r.inspect}"
      FileUtils.rm_rf(rec_id)
    end
  end
  
  def convert_node_value_to_file_value(node_key_value)
    file_base_value = node_key_value.to_s.gsub("::", "_")
    file_value = File.join(@user_datastore_location, file_base_value)
  end
  
end 
end
