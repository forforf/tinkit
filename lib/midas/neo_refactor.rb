#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')
require Tinkit.helpers 'log_helper'

#Replace by using gemspce/Gemfile
require_relative "../../../midas/lib/midas"

#Define add, subtract and replace methods for different data operations
module NodeElementOperationsData
  module DefaultOps
    #ToDo: Add :get for KeyValues
    OpsList = [:add, :subtract, :replace]
    #Static Ops do not change anything
    StaticOps = {
      :add => lambda{|*args| self },
      :subtract => lambda{|*args| self },
      :replace => lambda{|*args| self }
    }

    ReplaceOps = {
      :add => lambda{|x| x},
      :subtract => lambda{|x| x == self ? nil : self}, #set to nil if self == x otherwise self
      :replace => lambda{|x| x}
    }

    ListOps = {
      :add => lambda{|x| [*self] + [*x]},
      :subtract => lambda{|x| [*self] - [*x]},
      :replace => lambda{|x| [*x]}
    }

    #self must be hash!
    KeyValReplaceOps = {
      :add => lambda{ |h| self.merge h},
      #remove key-val only if exact match
      :subtract => lambda{|h| self.delete_if{|k,v| (h.keys.include? k) && (h[k] == self[k])} },
      :replace => lambda{ |h| h }
    }

    #if identical key, add new val to list
    KeyValListOps = {
      :add => lambda do |h|
        combined_keys = (h.keys + self.keys).uniq
        combined = {}
        combined_keys.each do |k|
          combined_vals = ([*self[k]] + [*h[k]]).uniq
          combined_vals.compact!
          combined[k] = combined_vals
        end
        combined
      end,
      :subtract => lambda do |h|
        difference = {}
        self.keys.each do |k|
          diff_vals = [*self[k]] - [*h[k]]
          diff_vals.uniq!
          diff_vals.compact!
          difference[k] = diff_vals
        end
        difference
      end,
      #replace and convert vals to arrays
      :replace => lambda{|h| h.inject({}){|memo,(k,v)| memo[k] = [*v]; memo} }
    }

    KeyValNestedOps = {
      :add => lambda do |other_hash|
        recurs_lambda = lambda do |h1, h2, memo, last_key|
          memo ||= {}
          h1_keys = h1.respond_to?(:keys) ? h1.keys : []
          h2_keys = h2.respond_to?(:keys) ? h2.keys : []
          all_keys = h1_keys + h2_keys
          all_keys.uniq!
          all_keys.each do |key|
            if h1[key] == h2[key]
              memo[key] = [ h1[key] ]
            else
              both_keys_exist = h1[key] && h2[key]
              both_keys_have_keys = h1[key].respond_to?(:keys) && h2[key].respond_to?(:keys)
              if both_keys_exist && both_keys_have_keys
                memo[key] = recurs_lambda.call(h1[key], h2[key], memo[key])
              else 
                memo[key] = [ h1[key], h2[key] ]
              end
            end
          end
          memo
        end
        result = nil
        self.tap do |this| 
          result = recurs_lambda.call(this, other_hash, nil)
        end
        result
      end,
   
      :subtract => lambda do |other_hash|
        recurs_lambda = lambda do |h1, h2, memo, last_key|
          memo ||= {}
          h1_keys = h1.respond_to?(:keys) ? h1.keys : []
          h1_keys.each do |key|
            if h1[key] == h2[key]
              memo[key] = begin
                h1[key] - h2[key] 
              rescue
                nil #h1[key]
              end
            else
              both_keys_exist = h1[key] && h2[key]
              both_keys_have_keys = h1[key].respond_to?(:keys) && h2[key].respond_to?(:keys)
              if both_keys_exist && both_keys_have_keys
                memo[key] = recurs_lambda.call(h1[key], h2[key], memo[key])
              elsif both_keys_exist  #means both don't have keys
                memo[key] = begin
                  h1[key] - h2[key] 
                rescue
                  h1[key]
                end
              elsif !(both_keys_exist) #one or both keys is nil
                memo[key] = h1[key]
              end
            end
          end
          memo
        end

        result = nil
        self.tap do |this| 
          result = recurs_lambda.call(this, other_hash, nil)
        end
        result
      end,

      :replace => lambda do |other_hash|
        recurs_lambda = lambda do |h1, h2, memo, last_key|
          memo ||= {}
          h1_keys = h1.respond_to?(:keys) ? h1.keys : []
          h2_keys = h2.respond_to?(:keys) ? h2.keys : []
          all_keys = h1_keys + h2_keys
          all_keys.uniq!
          all_keys.each do |key|
            if h1[key] == h2[key]
              memo[key] = h2[key]
            else
              both_keys_exist = h1[key] && h2[key]
              both_keys_have_keys = h1[key].respond_to?(:keys) && h2[key].respond_to?(:keys)
              if both_keys_exist && both_keys_have_keys
                memo[key] = recurs_lambda.call(h1[key], h2[key], memo[key])
              elsif both_keys_exist  #means both don't have keys
                memo[key] = h2[key]
              elsif !(both_keys_exist) #one or both keys is nil
                memo[key] = h2[key]
              end
            end
          end
          memo
        end
        result = nil
        self.tap do |this| 
          result = recurs_lambda.call(this, other_hash)
        end
        result
      end

    }

    BindList = {
      :id => StaticOps,
      :label => ReplaceOps,
      :tags => ListOps,
      :id_lookup => KeyValReplaceOps,
      :group_lists => KeyValListOps,
      :nested_data => KeyValNestedOps
    }
  end
end


NodeElementOperations = Midas::Factory.make(key_method_map = NodeElementOperationsData::DefaultOps::BindList)

=begin
#Tinkit Backward compatibility
class NodeElementOperations
  include NodeElementOperationsData
  #Create methods of the form #<key>_<operation>
  #e.g., id_add  #will perform StaticOps Add function on value of :id key
  DefaultOps::BindList.each do |key, op_type|
    DefaultOps::OpsList.each do |op_meth|
      meth_name = "#{key}_#{op_meth}".to_sym
      block = op_type[op_meth]
      p block
      #TODO  Figure out how to set this up, requires looking at how it is used
      define_method( meth_name, self.__send__(key).__send__(op_meth) )
    end
  end
end
=end
