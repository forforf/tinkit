#This is more of a guideline than an abstract class
#that must be inherited from.

#module <PersistentLayer>Interface
  #persistent layer helper classes/modules can go here
  
  class FilesMgrBase
    #persistent layer class initialization code
    #persistent layer accessors

    def initialize(glue_env, node_key_value)
       #persistent layer object creation
       raise NotImplementedError
    end

    def add(node, file_datas)
      raise NotImplementedError
    end
    
    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      raise NotImplementedError
    end

    def get_attachments_metadata(node)
      raise NotImplementedError
    end

    def get_raw_data(node, file_basename)
      raise NotImplementedError
    end
    
    def list(node)
      raise NotImplementedError
    end    

    def subtract(node, file_basenames)
      raise NotImplementedError
    end
    
    def subtract_all(node) #can be called from subtract using :all instead of a list of file_basenames
      raise NotImplementedError
    end
    
    def subtract_some(node, file_basenames)
      raise NotImplementedError
    end

    #other persistent layer methods needed

  end
#end of module
