require "couchrest"
require "tinkit"

module BufsEnv
  def self.builder(model_name, node_class_id, user_id, path, host = nil)
        #binding data (note this occurs in two different places in the env)

    key_fields = {:required_keys => [:my_category],
                         :primary_key => :my_category }
    #data model
    field_op_set ={:my_category => :static_ops,
                          :description => :replace_ops,
                             :parent_categories => :list_ops,
                             :links => :key_list_ops }
    #op_set_mod => <Using default definitions>

    data_model = {:field_op_set => field_op_set, :key_fields => key_fields}

    #persistence layer model
    pmodel_env = { :host => host,
                          :path => path,
                          :user_id => user_id}
    persist_model = {:name => model_name, :env => pmodel_env, :key_fields => key_fields}

    #final env model
    env = { :node_class_id => node_class_id,
                :data_model => data_model,
                :persist_model => persist_model }
  end
end


BufsDB = CouchRest.database!("http://127.0.0.1:5984/bufs_to_joha")
bufs_env = BufsEnv.builder("couchrest", "JohaTestClass", "joha_test_user", BufsDB.uri, BufsDB.host)

bufs_class = TinkitNodeFactory.make(bufs_env)
bufs_data = bufs_class.all

TinkitDB = CouchRest.database!("http://127.0.0.1:5984/joha_test_data")

tinkit_env = TinkitNodeFactory.env_formatter("couchrest", "JohaTestClass", "joha_test_user", TinkitDB.uri, TinkitDB.host)

tinkit_class = TinkitNodeFactory.make(tinkit_env)

#tinkits = []
bufs_data.each do |bufs_node|
  tinkit_data = {}
  tinkit_data[:id] = "tid_#{bufs_node.my_category}"
  tinkit_data[:label] = bufs_node.my_category
  tinkit_data[:description] = bufs_node.description
  tinkit_data[:links] = bufs_node.links
  tinkit_data[:parents] = bufs_node.parent_categories
  tinkit_data[:notes] = []
  tinkit_data[:update_log] = ["import from bufs format"]
  
  #tinkits << tinkit_data
  tinkit_node = tinkit_class.new(tinkit_data)
  p "Saving ID #{tinkit_node.id}"
  tinkit_node.__save
  #Handle Attachments
  atts = bufs_node.attached_files
  if atts
    atts.each do |att|
      tinkit_node.__import_attachment(att, bufs_node.__export_attachment(att))
    end
  end
end

#require 'pp'
#pp tinkits

