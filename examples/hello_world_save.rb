require '../lib/tinkit'  #<-- to be replaced by gem

# First we need to describe the environment for bufs
# we will use the file system as our persistend store and
# the default data model to simplify things a bit.
#
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
env = {:node_class_id => "HelloWorldClass",
           :persist_model => {
             :name => "filesystem",
             :key_fields => {
               :required_keys => [:id],
               :primary_key => :id,
             },
             :env => {
               :user_id => "me",
               :path => "/tmp/tinkit_hello_world_test/"
             }
           }
}

TinkitNodeFactory.make(env)
#=> Tinkit::HelloWorldClass
hello_world_node = Tinkit::HelloWorldClass.new( {:id => 'helloworld_id', :data => "Hello World"} )

#to see your node's data, just call the fields as a method call
p hello_world_node.id
p hello_world_node.data
#to save your node to the data store
hello_world_node.__save
