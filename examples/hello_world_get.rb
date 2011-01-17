require '../lib/tinkit'  #<-- to be replaced by gem

# So time to check the persistence.
# If we provide the environment again
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

#and make the class
TinkitNodeFactory.make(env)
#=> Tinkit::HelloWorldClass

#we should be able to get to our data
#we can get all data (array of all nodes)
puts Tinkit::HelloWorldClass.all.first.data

#or by the primary key id
puts Tinkit::HelloWorldClass.get("helloworld_id").data

#or by searching for data
puts Tinkit::HelloWorldClass.find_nodes_where(:data, :equals, "Hello World").first.data