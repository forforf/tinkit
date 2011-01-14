#Bufs directory structure defined in lib/helpers/require_helpers
require Bufs.midas 'bufs_data_structure'
require Bufs.glue '/couchrest/couchrest_files_mgr'
require Bufs.helpers 'log_helper'
require Bufs.helpers 'hash_helpers'

module CouchRestViews
  #FIXME MAJOR BUG
  #Views should be an instance to a user class
  #not a module, otherwise, last one set gets all the goodies
  
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)
  
  #Constants (pulling out magic text embedded in program)
  #Changing these will break compatibility with earlier records
  ClassViewAllName = "all"   #view name stored in the couch db design doc
  ClassNamespaceKey = "all_this_class"  #couch db record that the bufs node class name is stored


  def self.set_view(db, design_doc, view_name, opts={})
    #raise view_name if view_name == :parent_categories
    #TODO: Add options for custom maps, etc
    #creating view in design_doc
    #puts "setting design_doc #{design_doc['_id']} with view: #{view_name.inspect} with map:\n #{opts.inspect}"
    design_doc.view_by view_name.to_sym, opts
    db_view_name = "by_#{view_name}"
    views = design_doc['views'] || {}
    view_keys = views.keys || []
    unless view_keys.include? db_view_name
      design_doc['_rev'] = nil
    end
    begin
      view_rev_in_db = db.get(design_doc['_id'])['_rev']
      #TODO: See if this can be simplified, I had forgotten the underscore for rev and added a bunch of other stuff
      #I also think I'm saving when it's not needed because I can't figure out how to detect if the saved view matches the
      #current view I want to run yet
      design_doc_uptodate = (design_doc['_rev'] == view_rev_in_db) && 
                                       (design_doc['views'].keys.include? db_view_name)
      design_doc['_rev'] = view_rev_in_db #unless design_doc_uptodate
      res = design_doc.save #unless design_doc_uptodate
      @@log.debug { "Save Design Doc Response: #{res.inspect}"} if @@log.debug?
      res
    rescue RestClient::RequestFailed
      if @@log.warn?
        @@log.warn { "Warning: Request Failed, assuming because the design doc was already saved?"}
      end
      if @@log.info?
        @@log.info { "Design doc_id: #{design_doc['_id'].inspect}"}
        @@log.info { "doc_rev: #{design_doc['_rev'].inspect}" }
        @@log.info { "db_rev: #{view_rev_in_db}" }
        @@log.info {"Code thinks doc is up to date? #{design_doc_uptodate.inspect}" }
      end
    end
  end


  def self.set_view_all(db, design_doc, model_name, datastore_location)
    view_name = "#{ClassViewAllName}_#{model_name}"
    namespace_id = ClassNamespaceKey
    record_namespace = "#{datastore_location}_#{model_name}"
    map_str = "function(doc) {
		  if (doc['#{namespace_id}'] == '#{record_namespace}') {
		     emit(doc['_id'], doc);
		  }
	       }"
    map_fn = { :map => map_str }
    self.set_view(db, design_doc, view_name, map_fn)
  end
  
  #Set static views.
#=begin
  def self.set_my_cat_view(db, design_doc, user_datastore_location)
    map_str = "function(doc) {
                   if (doc.#{ClassNamespaceKey} =='#{user_datastore_location}' && doc.my_category ){
                     emit(doc.my_category, doc);
                  }
               }"
    map_fn = { :map => map_str }
    #TODO: Tied to datastructure
    self.set_view(db, design_doc, :my_category, map_fn)
  end
#=end
  #TODO: Tied to datastructure
  def self.by_my_category(moab_data, user_datastore_location, match_key)
    db = moab_data[:db]
    design_doc = moab_data[:design_doc]
    map_str = "function(doc) {
                   if (doc.bufs_namespace =='#{user_datastore_location}' && doc.my_category ){
                     emit(doc.my_category, doc);
                  }
               }"
    map_fn = { :map => map_str }
    self.set_view(db, design_doc, :my_category, map_fn)
    raw_res = design_doc.view :by_my_category, :key => match_key
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"]}
  end 

  #TODO: Tied to datastructure
  def self.by_parent_categories(moab_data, user_datastore_location, match_keys)
    db = moab_data[:db]
    design_doc = moab_data[:design_doc]
    map_str = "function(doc) {
                if (doc.bufs_namespace == '#{user_datastore_location}' && doc.parent_categories) {
                       emit(doc.parent_categories, doc);
                    };
                };"
          #   }"
    map_fn = { :map => map_str }

    self.set_view(db, design_doc, :parent_categories, map_fn)
    raw_res = design_doc.view :by_parent_categories
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"] if r["value"]["parent_categories"].include? match_keys}
  end
end
  module CouchrestViews
    DefineViews = {
      :value_match => nil, 
      :included_match => nil,
      :key_of_included_match => nil
    }
    
    def view_map(namespace_label, datastore_location, field_name)
      "function(doc) {
          if (doc.#{namespace_label} =='#{user_datastore_location}' && doc.#{field_name} ){
               emit(doc.#{field_name}, doc);
          }
     }"
    end
   
    def set_view_value_match(db, design_doc, namespace_key, user_datastore_location, field_name)
      map_function = { :map => view_map(namespace_key, user_datastore_location, field_name) } 
      CouchRestViews.set_view(db, design_doc, field_name, map_function)
    end
    
    
    def call_view(field_name, moab_data, namespace_key, user_datastore_location, match_key, view_name = nil)
      db = moab_data[:db]
      design_doc = moab_data[:design_doc]
      set_view_value_match(db, design_doc, namespace_key, user_datastore_location, field_name)
      view_name = view_name || "by_#{field_name}"
      raw_results = design_doc.view view_name, :key => match_key
      rows = raw_results["rows"]
      records = rows.map{|r| r["value"]}
    end
    
  end

module CouchrestEnv
  #EnvName = :couchrest_env  #name for couchrest environments

class GlueEnv
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)

  include CouchRest::Mixins::Views::ClassMethods
  include CouchrestViews
  
  #used to identify metadata for models (should be consistent across models)
  #ModelKey = :_id 
  VersionKey = :_rev
  #NamespaceKey = :bufs_namespace
  PersistLayerKey = :_id  #required by CouchDb to be unique in DB
  
  CouchMetadataKeys = [:_pos, :_deleted_conflicts, :couchrest, :all_this_class] #possibly more, these keys are ignored
  QueryAllStr = "by_all_bufs".to_sym
  AttachClassBaseName = "MoabAttachmentHandler"
  DesignDocBaseName = "CouchRestEnv" #used to be module name
  
                      
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
                                :db,
                                :design_doc,
                                :query_all,
                                :attachment_base_id,
                                :attachClass 

  def initialize(persist_env, data_model_bindings)
    couchrest_env = persist_env[:env]
    couch_db_host = couchrest_env[:host]
    db_name_path = couchrest_env[:path]
    @user_id = couchrest_env[:user_id]
    @model_name = persist_env[:name]
    
    #data_model_bindings from NodeElementOperations
    key_fields = data_model_bindings[:key_fields] 
    initial_views_data = data_model_bindings[:views] || []
    
    #FIXME: Major BUG!! when setting multiple environments in that this may cross-contaminate across users
    #if those users share the same db.  Testing up to date has been users on different dbs, so not an issue to date
    #also, one solution might be to force users to their own db? (what about sharing though?)
    #The problem is that there is one "query_all" per database, and it gets set to the last user class
    #that sets it.  [Is this still a bug? 12/16/10]
    #@user_id = db_user_id
    #user_attach_class_name = "UserAttach#{db_user_id}"
    #the rescue is so that testing works
    #begin
    #  attachClass = UserNode.const_get(user_attach_class_name)
    #rescue NameError
    #  puts "Warning:: Multiuser support for attachments not enabled. Using generic Attachment Class"
    #  attachClass = CouchrestAttachment
    #end
    couch_db_location = set_db_location(couch_db_host, db_name_path)
    @db = CouchRest.database!(couch_db_location)
    @model_save_params = {:db => @db}
    @persist_layer_key = PersistLayerKey
    
    #@collection_namespace = CouchrestEnv.set_collection_namespace(db_name_path, @user_id)
    #@user_datastore_location = CouchRestEnv.set_user_datastore_location(@db, @user_id)
    @user_datastore_location = set_namespace(db_name_path, @user_id)
    @design_doc = set_couch_design(@db, @user_id)#, @collection_namespace)
    @node_key = key_fields[:primary_key]     
    #
    @define_query_all = QueryAllStr #CouchRestEnv.query_for_all_collection_records
    
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @model_key = @node_key #ModelKey #CouchRestEnv::ModelKey
    @version_key = VersionKey #CouchRestEnv::VersionKey
    @namespace_key = @model_name #NamespaceKey #CouchRestEnv::NamespaceKey
    #TODO: Need to investigate whether to keep model_key = node_key in metadata
    @metadata_keys = [@persist_layer_key, @version_key, @namespace_key] + CouchMetadataKeys #CouchRestEnv.set_db_metadata_keys #(@collection_namespace)
 
    @views = CouchRestViews
    @views.set_view_all(@db, @design_doc, @model_name, @user_datastore_location)
    
    @views.set_my_cat_view(@db, @design_doc, @user_datastore_location)
    
    
    
    #set new view
    initial_views_data.each do |view_name, view_data|
      set_view_value_match(@db, @design_doc, @namespace_key, @user_datastore_location, view_data[:field])
    end
    
    #@views.set_new_views(xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
    
    attach_class_name = "#{AttachClassBaseName}#{@user_id}"
    @attachClass = set_attach_class(@db.root, attach_class_name) 
    @moab_data = {:db => @db, 
                            :design_doc => @design_doc, 
                            :attachClass => @attachClass}
    #TODO: Have to do the above, but want to do the below
    #@attachClass = set_attach_class(@db.root, attach_class_name)
    @_files_mgr_class = CouchrestInterface::FilesMgr
  end
  
  #TODO Need to fix some naming issues before bringing this method over into the glue environment
  #def set_attach_class(db_root_location, attach_class_name)
  #  dyn_attach_class_def = "class #{attach_class_name} < CouchrestAttachment
  #    use_database CouchRest.database!(\"http://#{db_root_location}/\")
  # 
  #    def self.namespace
  #      CouchRest.database!(\"http://#{db_root_location}/\")
  #    end
  #  end"
  #  
  #  self.class.class_eval(dyn_attach_class_def)
  #  self.class.const_get(attach_class_name)
  #end  
  
  def set_db_location(couch_db_host, db_name_path)
      couch_db_host.chop if couch_db_host =~ /\/$/ #removes any trailing slash
      db_name_path = "/#{db_name_path}" unless db_name_path =~ /^\// #check for le
      couch_db_location = "#{couch_db_host}#{db_name_path}"
  end

  #TODO: MAJOR Refactoring may have broken compatibility with already persisted data, need to 
  #figure out tool to migrate persisted data when changes occur
  #TODO: MAJOR Namespace should not be bound to the underlying model it should be bound to user data only
  def set_namespace(db_name_path, db_user_id)
      lose_leading_slash = db_name_path.split("/")
      lose_leading_slash.shift
      db_name = lose_leading_slash.join("")
      #namespace = "#{db_name}_#{db_user_id}"
      namespace = "#{db_user_id}"
  end
    
  def set_user_datastore_location(db, db_user_id)
      "#{db.to_s}::#{db_user_id}"
  end  
  
  def set_couch_design(db, user_id) #, view_name)
      design_doc = CouchRest::Design.new
      design_doc.name = "#{DesignDocBaseName}_#{user_id}_Design"
      #example of a map function that can be passed as a parameter if desired (currently not needed)
      #map_function = "function(doc) {\n  if(doc['#{@@collection_namespace}']) {\n   emit(doc['_id'], 1);\n  }\n}"
      #design_doc.view_by collection_namespace.to_sym #, {:map => map_function }
      design_doc.database = db
      begin
        design_doc = db.get(design_doc['_id'])
      rescue RestClient::ResourceNotFound
        design_doc.save
      end
      design_doc
    end  
    
    def set_attach_class(db_root_location, attach_class_name)
    dyn_attach_class_def = "class #{attach_class_name} < CouchrestAttachment
      use_database CouchRest.database!(\"http://#{db_root_location}/\")
 
      def self.namespace
        CouchRest.database!(\"http://#{db_root_location}/\")
      end
    end"
    
    self.class.class_eval(dyn_attach_class_def)
    self.class.const_get(attach_class_name)
  end
  
  def query_all  #TODO move to ViewsMgr and change the confusing accessor/method clash
    #breaks everything -> self.set_view(@db, @design_doc, @collection_namespace)
    view_name = "by_#{CouchRestViews::ClassViewAllName}_#{@model_name}"
    #raise view_name
    raw_res = @design_doc.view view_name #@define_query_all
    raw_data = raw_res["rows"]
    data = raw_data.map {|rec| HashKeys.str_to_sym( rec['value'] ) }
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
      else
        raise "Couldn't determine relationship between stored data and lookup data"
    end #case
    @@log.info {"Found #{res.size} nodes where #{key} #{relation} #{this_value}"} if @@log.info?
    return res    
  end
  
  def find_equals(key, this_value)
    results =[]
    query_all.each do |record|
      test_val = record[key]
      results << record  if test_val == this_value
    end
    @@log.debug {"Found equals results: #{results.inspect}"} if @@log.debug?
    results 
  end
  
  def find_contains(key, this_value)
    #TODO: Make a view for this rather than doing it in ruby
    results =[]
    query_all.each do |record|
      test_val = record[key]
      results << record  if find_contains_type_helper(test_val, this_value)
    end
    @@log.debug {"Found contains results: #{results.inspect}"} if @@log.debug?
    results 
  end
  
  def find_contains_type_helper(stored_data, this_value)
    resp = nil
    #stored_data = jparse(stored_dataj)
    if stored_data.respond_to?(:"include?")
      resp = (stored_data.include?(this_value))
    else
      resp = (stored_data == this_value)
    end
    return resp
  end


  def save(user_data)
    #I thinkthis was why I originally created the namespace concept but reconciliation is now required
    pk_data = generate_pk_data(user_data[@model_key])
    record_namespace = "#{@user_datastore_location}_#{@model_name}"
    #Major TODO: Deconflict module CouchrestView and CouchRestViews
    namespace_key = CouchRestViews::ClassNamespaceKey
    pl_metadata = {PersistLayerKey => pk_data,  namespace_key => record_namespace}
    new_data = user_data.dup.merge(pl_metadata)
    db = @model_save_params[:db]
    
    raise "No database found to save data" unless db
    raise "No CouchDB Key (#{PersistLayerKey}) found in data: #{new_data.inspect}" unless new_data[PersistLayerKey]
    raise "No [#{@model_key}] key found in model data: #{new_data.inspect}" unless new_data[@model_key]
    
    model_data = HashKeys.sym_to_str(new_data) 
    #db.save_doc(model_data)
    begin
      #TODO: Genericize this
      res = db.save_doc(model_data)
    rescue RestClient::RequestFailed => e
      #TODO Update specs to test for this
      if e.http_code == 409
        doc_str = "Document Conflict in the Database." 
        @@log.warn { doc_str } if @@log.warn?
        existing_doc = db.get(model_data['_id'])
        rev = existing_doc['_rev']
        data_with_rev = model_data.merge({'_rev' => rev})
        res = db.save_doc(data_with_rev)
      else
	      raise "Request Failed -- Response: #{res.inspect} Error:#{e}"\
	      "\nAdditonal Data: model params: #{model_save_params.inspect}"\
	      "\n                model data: #{model_data.inspect}"\
	      "\n                all data: #{new_data.inspect}"
      end
    end
  end 

  def get(id)
    #id can be the model id or the persist layer id
    pk_data = if id.include? self.class.name
      id
    else
      generate_pk_data(id)
    end
    #maybe put in some validations to ensure its from the proper collection namespace?
    #pk_data = id #generate_pk_data(id)
    #Major TODO: Deconflict module CouchrestView and CouchRestViews
    namespace_key = CouchRestViews::ClassNamespaceKey
    #options, use native couchdb _id or buidl a view for the model key
    #currently opting for using _id, but this requires rebuilding the primary key data
    #which is not an ideal solution
    rtn = begin
      node = @db.get(pk_data)
      node = HashKeys.str_to_sym(node)
      node.delete(PersistLayerKey)
      node.delete(namespace_key)
      node
    rescue RestClient::ResourceNotFound => e
      nil
    end
    rtn
  end

  #Not tested in factory tests (but is in couchrest tests)
  def destroy_node(model_metadata)
    #att_doc = node.my_GlueEnv.attachClass.get(node.attachment_doc_id) if node.respond_to?(:attachment_doc_id)
    attachClass = @moab_data[:attachClass]
    att_doc_id = attachClass.uniq_att_doc_id(model_metadata[@persist_layer_key])
    att_doc = attachClass.get(att_doc_id) if att_doc_id
    #raise "Destroying Attachment #{att_doc.inspect} derived from #{@model_metadata.inspect} "
    att_doc.destroy if att_doc
    db_destroy(model_metadata)
  end
  
  #TODO: update glue models so that it's id and rev that are explicitly needed
  #which begs the question whether rev is supported or not
  def db_destroy(model_metadata)
    id_to_delete = model_metadata[@persist_layer_key] ||  generate_pk_data(model_metadata[@node_key])
    @@log.info { "Destroy in DB, Key: #{id_to_delete.inspect} in #{model_metadata.inspect}" } if @@log.info?
    
    rev_to_delete = model_metadata[@version_key] || @db.get(id_to_delete)['_rev']  
    doc_to_delete = {'_id' =>  id_to_delete, '_rev' => rev_to_delete }
 
    @@log.debug { "Attempting to Delete: #{doc_to_delete.inspect}" } if @@log.debug?
    begin
      @db.delete_doc(doc_to_delete)
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{model_metadata[@model_key]} node"
      #Code here was deleting the latest version, but rather than wait for an error, it was proactively checked
      #so this block may not be needed any more
      #node = node.class.get(model_metadata[@model_key]) #(model_metadata['_id'])
      #db_destroy(model_metadata)
    end
  end
 

  #def xdestroy_node(node)
  #  CouchRestEnv::destroy_node(node)
  #  node = nil
  #end

  #I hope this can be replaced by the generate_pk_data, but need to make sure
  #FIXME: Actually it has to be
  def generate_model_key(namespace, node_key_value)
    #TODO: Make sure namespace is portable across model migrations (must be diff database)
    #"#{namespace}::#{node_key}"   # <== original if the below ends up breaking stuff
    #"#{node_key}"
    generate_pk_data(node_key_value)
  end
  
  def generate_pk_data(record_id)
    #url_friendly_class_name = self.class.name.gsub('::','-')
    "#{user_id}:#{self.class.name}:#{record_id}"
  end

  #some models have additional processing required, but not this one
  def raw_all
    query_all
  end



  #TODO: Investigate if Couchrest bulk actions or design views will assist here
  #fixed to delete orphaned attachments, but this negates much of the advantage of using this method in the first place
  #or perhaps using a close to the metal design view based on the class name?? (this may be better)
  def destroy_bulk(user_records_to_delete)
    #TODO: Investigate why mutiple ids may be returned for the same record
    #Answer Database Corruption
    user_records_to_delete.uniq!
    #puts "List of all records: #{user_records_to_delete.map{|r| r['_id']}.inspect}"

    user_records_to_delete.each do |user_rec|
      begin
        db_key = user_rec[@persist_layer_key] || generate_pk_data(user_rec[@model_key])
        att_doc_id = attachClass.uniq_att_doc_id(db_key)
        r = @db.get(db_key )
        @db.delete_doc(r)
        begin
          att_doc = @db.get(att_doc_id)
        rescue
          att_doc = nil
        end
        @db.delete_doc(att_doc) if att_doc
      rescue RestClient::RequestFailed
        @@log.warn{ "Warning:: Failed to delete document?" } if @@log.warn?
      end
    end
    nil #TODO ok to return nil if all docs destroyed? also, not verifying
  end
end 
end
