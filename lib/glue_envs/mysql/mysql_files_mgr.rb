require 'dbi'
require 'json'

require Tinkit.helpers 'mime_types_new'
require Tinkit.helpers 'tk_escape.rb'

module MysqlInterface
  class FilesMgr

    class << self; attr_accessor :dbh; end
    @@home_dir = ENV["HOME"]
    @@my_pw = File.open("#{@@home_dir}/.locker/tinkit_mysql"){|f| f.read}.strip
    
    @dbh = DBI.connect("DBI:Mysql:tinkit:localhost", "tinkit", @@my_pw)

    #Table Structure
    MySqlPrimaryKey = '__pkid-file'
    NodeName = 'node_name'
    Basename = 'basename'
    ContentType = 'content_type'
    ModifiedAt = 'modified_at'
    RawContent = 'raw_content'
    FileTableKeys = [MySqlPrimaryKey, NodeName, Basename, ContentType, ModifiedAt, RawContent]
    
    TablePostFix = "_files" #TODO: See if you can get away from that
        #options: include in model_save_params, or let base node pass on methods to
        #underlying glue env (probably this)
    
    attr_accessor :file_table_name
    
    def initialize(glue_env, node_key_value)
      @dbh = self.class.dbh
      @file_table_name = glue_env.file_mgr_table
    end

    def add(node, file_datas)
      filenames = []
      file_datas.each do |file_data|
        filenames << file_data[:src_filename]
      end
      
      filenames.each do |filename|
        #p File.open(filename, 'rb'){|f| f.read}
        basename = File.basename(filename)
        #derive content_type
        content_type = MimeNew.for_ofc_x(basename)
        #derive modified time from file
        modified_at = File.mtime(filename).to_s
        rb = 'rb' #lazily avoiding escape issues
        node_name = node.__send__(node.my_GlueEnv.model_key.to_sym)
        fields_str =   "`#{NodeName}`, `#{Basename}`, `#{ContentType}`, `#{ModifiedAt}`, `#{RawContent}`"
        prep_sql = "REPLACE INTO `#{@file_table_name}` (#{fields_str})
        VALUES ( ?, ?, ?, ?, ?)"
        sth = @dbh.prepare(prep_sql)
        values_input = [node_name, basename, content_type, modified_at, File.open(filename, rb){|f| f.read}]
        sth.execute(*values_input)
      end
      filenames.map {|f| TkEscape.escape(File.basename(f))} #return basenames
    end
    
    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      raise "No Data provided for file" unless raw_data
      if file_modified_at
        modified_at = file_modified_at
      else
        modified_at = Time.now.to_s
      end
      
      attachment_package = {}
      node_name = node.__send__(node.my_GlueEnv.model_key.to_sym)
      fields_str =   "`#{NodeName}`, `#{Basename}`, `#{ContentType}`, `#{ModifiedAt}`, `#{RawContent}`"
      prep_sql = "REPLACE INTO `#{@file_table_name}` (#{fields_str})
      VALUES ( ?, ?, ?, ?, ?)"
      sth = @dbh.prepare(prep_sql)
      values_input = [node_name, attach_name, content_type, modified_at, raw_data]
      sth.execute(*values_input) 
      return [attach_name]
    end
    
    def list(node)
      model_key = node.my_GlueEnv.model_key
      
      sql = "SELECT `#{Basename}` FROM `#{@file_table_name}`
       WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'"
      sth = @dbh.prepare(sql)
      rtn = []
      sth.execute
      while row=sth.fetch do
        rtn << row.to_h
      end
      #rtn
      sth.finish
      basenames =  rtn.map{|basename_hash| basename_hash.values}.flatten
    end

    def get_raw_data(node, file_basename)
      model_key = node.my_GlueEnv.model_key
      sql = "SELECT `#{RawContent}` FROM `#{@file_table_name}`
       WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'
       AND `#{Basename}` = '#{file_basename}'"
      #puts "Raw Data SQL: #{sql}"
      sth = @dbh.prepare(sql)
      rtn = []
      sth.execute
      while row=sth.fetch do
        rtn << row.to_h
      end
      #rtn
      sth.finish
      rtn_val = rtn.first || {} #remember in production to sort on internal primary id (once delete revisions works)
      rtn_val['raw_content'] 
    end

      #todo change name to get_files_metadata
    def get_attachments_metadata(node)
      files_md = {}
      md_list = FileTableKeys
      md_list.delete(RawContent)
      md_fields = md_list.join("`, `")
        
      model_key = node.my_GlueEnv.model_key
      sql = "SELECT `#{md_fields}` FROM `#{@file_table_name}`
       WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'"
      sth = @dbh.prepare(sql)
      rtn = []
      sth.execute
      while row=sth.fetch do
        rtn << row.to_h
      end
      #rtn
      sth.finish
      objects = rtn
      objects.each do |object|
        obj_md = object 
        #speputs "Obj It: #{obj_md.inspect}"
        obj_md_file_modified = obj_md["modified_at"]
        obj_md_content_type = obj_md["content_type"]
        new_md = {:content_type => obj_md_content_type, :file_modified => obj_md_file_modified}
        new_md.merge(obj_md)  #where does the original metadata go?
        #p new_md.keys
        files_md[obj_md["basename"]] = new_md
        #puts "Obj METADATA: #{new_md.inspect}"
      end
      files_md
    end#def

    def subtract(node, file_basenames)
      if file_basenames == :all
        subtract_all(node)
      else
        subtract_some(node, file_basenames)
      end
    end
    
    def subtract_all(node)
      model_key = node.my_GlueEnv.model_key
      sql = "DELETE FROM `#{@file_table_name}`
            WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'"
      @dbh.do(sql)
    end
    
    def subtract_some(node, file_basenames)
      file_basenames = [file_basenames].flatten
      model_key = node.my_GlueEnv.model_key
      #probalby get better performance by changing the sql match query
      #rather than iterating
      file_basenames.each do |file_basename|
        sql = "DELETE FROM `#{@file_table_name}`
            WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'
            AND `#{Basename}` = '#{file_basename}'"
       
        @dbh.do(sql)
      end
    end#def
  end#class
end#mod
