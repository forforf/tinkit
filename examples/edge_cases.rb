require '../lib/tinkit'  #<-- to be replaced by gem

#What happens if we define two different users with the same class ...?
env1 = {:node_class_id => "HelloWorldClass",
           :persist_model => {
             :name => "filesystem",
             :key_fields => {
               :required_keys => [:id],
               :primary_key => :id,
             },
             :env => {
               :user_id => "me",
               :path => "/tmp/bufs_hello_world_test/"
             }
           }
}


env2 = {:node_class_id => "HelloWorldClass",
           :persist_model => {
             :name => "filesystem",
             :key_fields => {
               :required_keys => [:id],
               :primary_key => :id,
             },
             :env => {
               :user_id => "you",
               :path => "/tmp/bufs_hello_world_test/"
             }
           }
}
TinkitNodeFactory.make(env1)
TinkitNodeFactory.make(env2)
#=> Tinkit::HelloWorldClass
user_me = Tinkit::HelloWorldClass.new( {:id => 'helloworld_id', :data => "Hello World Me"} )
user_me.__save
user_you = Tinkit::HelloWorldClass.new( {:id => 'helloworld_id', :data => "Hello World You"} )
user_you.__save

p Tinkit::HelloWorldClass.all.first.data
#=> Ducked Punched myself


