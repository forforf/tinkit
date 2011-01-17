#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Tinkit.lib 'tinkit_base_node'
require Tinkit.helpers 'log_helper'

# The factory for building Tinkit Classes.  Each Tinkit class is roughly equivalent to other ORM classes (Rails, Couchrest, etc).
#  It has class methods for operating across the entire collection, and each instance of that class is an individual node. So:
#     SomeTinkitClass.all  #=> returns all records maintained by SomeTinkitClass as Tinkit nodes
#     some_tinkit_node = SomeTinkitClass.all.first
#     yet_another_tinkit_node = SomeTinkitClass.find_node_where(:my_data, :contains, "foo").first
#     another_tinkit_node = SomeTinkitClass.get(node_primary_key_value)
#
#  Note on record/node terminology.  Records and Nodes are essentially a collection of data that corresponds to an instance of
#  the Tinkit class.  The difference is that I try to use the term "record" when referring to the persisted layer data object, and
#  node when referring to the Tinkit wrapped data object.
class TinkitNodeFactory 
  #Set Logger
  @@log = TinkitLog.set(self.name, :debug)

  # Builds the class from the provided environment
  # the environment takes the following form
  #   :node_class_id  -  The Name of the class to create
  #   :persist_model  -  Information to model the user data in the persistence layer
  #   :env                 -  Information to set up the persistence layer
  #
  #   :persist_model fields
  #       :name  -  The name of the persistence layer to use.
  #                    This name must match one of the persistent layers "glue" environments
  #                     Out of the box, tinkit currently supports
  #                         :filesystem - basic filesystem interface (linux only right now)
  #                         :couchrest  - interface to CouchDB, requires a CouchDB instance (will work with CouchOne as well)
  #                         :mysql        - interface to a MySQL instance (I've only tested local mysql instances)
  #                         :sdb_s3      - interface to Amazon Web Services databases, requires AWS account (SDB for node data, S3 for files)
  #                         other persistent layers can be supported and added by creating the appropriate plugin in the glue_envs directory  
  #
  #       :key_fields  -  Identifies the primary key and any required keys. There can only be a single primary key, but multiple required keys
  #           :primary_key     -  The data that identifies the node. This key must be unique for each node within the tinkit node class
  #           :required_keys  -   List of keys required, should contain primary key.
  #
  #
  #   :env fields
  #       :user_id  -  This id is propagated to the persistence layer to segregate content into different contexts if necessary. A classic
  #                         example would be to give multiple users there own segregated persistence layer, before segregating by tinkit class.
  #                         Important note: persistent layer context segregation is not enforced in the tinkit runtime environment.  This means that if I
  #                         used the same node_class_id for two different user_ids in the same runtime instance of tinkit, name collisions
  #                         would occur. In other words, if user_ids :batman and :robin both had class ids of :BatCloset, then the contents 
  #                         and location of :BatCloset will be unpredictable (roughly similar to multi-thread behavior in a unsafe thread environment)
  #                         Having :batman with :BatmanCloset, and :robin with :RobinCloset would work fine, and if a shared closet was needed, you 
  #                         could create a class called :SharedCloset (user_id doesn't matter) and progamattically update it as dictated by application needs.
  #                         tl;dr:  Don't duck punch yourself.  
  #
  #     :path  -  Persistence layer location.  The particulars vary by persistence layer, but in general it says "this is where the persistence layer is gonna live"
  #                        filesystem  -  The path to the directory for all tinkit persisted data (created if it doesn't exist)
  #                         couchrest  -  The URL of the couchrest database to use (error if there is no CouchDB at that location)
  #                         mysql        -   A name prepended to mysql tables to keep tables unique (created if it doesn't exist)
  #                         sdb_s3      -  Simple DB domain (created if it doesn't exist)
  #
  #   Example:
  #
  #   env = {:node_class_id => "HelloWorldClass",
  #                 :persist_model => {
  #                       :name => "filesystem",
  #                       :key_fields => {
  #                               :required_keys => [:id],
  #                               :primary_key => :id,
  #                        },
  #                 :env => {
  #                       :user_id => "me",
  #                       :path => "/tmp/tinkit_hello_world_test/"
  #                 }
  #           }
  #   }
  #
  def self.make(node_env)
    TinkitLog.log_raise "No Node Environment provided" unless node_env
    TinkitLog.log_raise "Empty Node Environment provided" if node_env.empty?
    TinkitLog.log_raise "Malformed Node Environment" unless node_env.respond_to?(:keys)
    TinkitLog.log_raise "Malformed Node Environment" unless node_env.keys.include? :persist_model

    #TODO: Make setting the environment thread safe
    #__user_doc_class_name = node_env[:node_class_id]
    user_doc_class_name = "Tinkit::#{node_env[:node_class_id]}"

    #Security TODO: remove spaces and other pototential injection issues
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{user_doc_class_name} < TinkitBaseNode
      
      class << self; attr_accessor :user_attachClass, end

      end"

    #Create the Tinkit Class
    TinkitNodeFactory.class_eval(dyn_user_class_def)
    
    docClass = Tinkit.const_get(node_env[:node_class_id])
        
    #TODO: Streamline the paramaters (maybe one env paramater?)
    class_environment = node_env[:persist_model]
    
    neo_env = node_env[:data_model] || {}
    
    neo = NodeElementOperations.new(neo_env)
    docClass.data_struc = neo  #TODO: Why is this parameter passed magically, vs the others passed normally?

    data_model_bindings = {:key_fields => neo.key_fields,
                                      #:data_ops_set => neo.field_op_set_sym,
                                      :views => neo.views}

    docClass.set_environment(class_environment, data_model_bindings)
    docClass
  end
end 
