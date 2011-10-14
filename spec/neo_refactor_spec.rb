#require helper for cleaner require statements
#require File.join(File.expand_path(File.dirname(__FILE__)), '/../lib/helpers/require_helper')

#require Tinkit.midas 'node_element_operations'
require_relative "../lib/midas/neo_refactor"

describe NodeElementOperations, "Defaults" do
  include NodeElementOperationsData

  it "should have a default set of operations" do
    neo = NodeElementOperations.new
    neo.class.midas_defs.should == DefaultOps::BindList
  end

  it "can do bindings for static operations" do
    neo = NodeElementOperations.new
    #neo defines :id as a static ops key
    bound_value = neo.bind_methods(:id, "Static ID")
    bound_value.add.should == "Static ID"
    bound_value.add("should ignore this").should == "Static ID"
    bound_value.subtract("should ignore this").should == "Static ID"
    bound_value.replace("should ignore this").should == "Static ID"
  end

  it "can perform neo replace operations" do
    neo = NodeElementOperations.new
    bound_value = neo.bind_methods(:label, "My Orig Label")
    bound_value.add("New Value").should == "New Value"
    bound_value.subtract("New Value").should == "My Orig Label"
    bound_value.subtract("My Orig Label").should == nil
    bound_value.replace("New Value").should == "New Value"
  end

  it "can replace itself" do
    neo = NodeElementOperations.new
    bound_value = neo.bind_methods(:label, "My Orig Label")
    bound_value.should == "My Orig Label"
    new_label = bound_value.replace("My New Label")
    new_label.should == "My New Label"
    bound_value.replace_self(new_label)
    bound_value.should == "My New Label"
  end

  it "can peform neo list operations" do
    neo = NodeElementOperations.new

    bound_value = neo.bind_methods(:tags, "A Tag")
    bound_value.add("Another Tag").should == ["A Tag", "Another Tag"]
    bound_value.subtract("A Tag").should == []
    bound_value.replace("Another Tag").should == ["Another Tag"]

    bound_value = neo.bind_methods(:tags, [:tag1, :tag2, :tag3])
    bound_value.add([:tag4, :tag5]).should == [:tag1, :tag2, :tag3, :tag4, :tag5]
    bound_value.subtract([:tag1, :tag3]).should == [:tag2]
    bound_value.replace([:tag4, :tag5]).should == [:tag4, :tag5]
  end

  it "can peform neo key value replace operations" do
    neo = NodeElementOperations.new
    data = { :a => "A", :b => "B", :c => "C" }
    bound_value = neo.bind_methods(:id_lookup, data)
    bound_value.add( {:d => "D"} ).should == {:a=>"A",:b=>"B",:c=>"C",:d=>"D"}
    bound_value.add( :b => "B" ).should == data
    bound_value.subtract( {:d => "D"} ).should == data
    bound_value.subtract( {:c => "C"} ).should == {:a=>"A", :b=>"B"}
    bound_value.subtract( {:a=>"A", :c=>"C"} ).should == {:b=>"B"}
    bound_value.replace( {:a=>"A", :d=>"D"} ).should ==  {:a=>"A", :d=>"D"}
  end

  it "can peform neo key value list replace operations" do
    neo = NodeElementOperations.new
    data = {:a => "A", :b => ["B", "BB"]}
    bound_value = neo.bind_methods(:group_lists, data)
    bound_value.add( {:c=>"C"} ).should == {:a=>["A"], :b=>["B", "BB"], :c=>["C"]}
    bound_value.add({:a=>"AA"}).should == {:a=>["A","AA"], :b=>["B", "BB"]}
    bound_value.subtract( {:b=>"B"} ).should == {:a=>["A"], :b=>["BB"]}
    bound_value.subtract( {:c=>"C"}).should == {:a=>["A"], :b=>["B", "BB"]}
    bound_value.subtract( {:a=>"A"}).should == {:a=>[], :b=>["B", "BB"]}
    bound_value.replace({:d=>"D", :e=>[:ee, :eee]}).should == {:d=>["D"], :e=>[:ee, :eee]}
  end

  it "can perfom new key value nested add operations" do
    neo = NodeElementOperations.new
    data = {:a =>{:aa=>"AA", :ab=>"AB"},:b=>{:bb=>"BB", :bn=>1},:d => "D"}
    bound_value = neo.bind_methods(:nested_data, data)
    operand = {
     :b => {:bn => 2, :bb => "BB"},
     :c => "C",
     :d => "D"
    }
    expected_result = {
      :a=>[{:aa=>"AA", :ab=>"AB"}, nil],
      :b=>{:bb=>["BB"], :bn=>[1, 2]},
      :d=>["D"],
      :c=>[nil, "C"]
    }
    bound_value.add( operand ).should == expected_result
  end

  it "can perfom new key value nested subtract operations" do
    neo = NodeElementOperations.new
    data = {
      :a =>{:aa=>"AA", :ab=>"AB"},
      :b=>{:bb=>"BB", :bn=>1},
      :d => "D"
    }
    bound_value = neo.bind_methods(:nested_data, data)
    operand = {
      :b => {:bn => 2, :bb => "BB"},
      :c => "C",
      :d => "D"
    }
    expected_result = {
      :a=>{:aa=>"AA", :ab=>"AB"},
      :b=>{:bb=>nil, :bn=>-1},
      :d=>nil
    }
    bound_value.subtract(operand ).should == expected_result
  end


  it "can perfom new key value nested replace operations" do
    neo = NodeElementOperations.new
    data = {
      :a =>{:aa=>"AA", :ab=>"AB"},
      :b=>{:bb=>"BB", :bn=>1},
      :d => "D",
      :e => 42
    }

    bound_value = neo.bind_methods(:nested_data, data)

    operand = {
      :a=> {:ab => "AZ"},
      :b => {:bn => 2, :bb => "BB"},
      :c => "C",
      :d => "D"
    }
    expected_result = {
      :a => {:aa=> nil, :ab => "AZ"},
      :b=>{:bb=>"BB", :bn=>2},
      :c => "C",
      :d=>"D",
      :e => nil
    }
    bound_value.replace(operand).should == expected_result
  end

end

=begin #belongs in Tinkit
describe NodeElementOperations, "Backwards Compatibility" do
  include NodeElementOperationsData

  it "should have the methods mapped to <key>_<op> === <key>.<op>" do
    neo = NodeElementOperations.new
    neo.id_add.should == "Hi"
  end
end
=end

