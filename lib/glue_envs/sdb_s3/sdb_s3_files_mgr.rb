#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../../../lib/helpers/require_helper')
require Bufs.helpers 'tk_escape'

require 'aws/s3'

module AWS::S3
    class NoSuchBucket < ResponseError
    end
    
    class BucketNotEmpty < ResponseError
    end
end

module SdbS3Interface

  class NilBucketError < StandardError
  end
  
  class FilesMgr
    include AWS
    AccessKey = ENV["AMAZON_ACCESS_KEY_ID"]
    SecretKey = ENV["AMAZON_SECRET_ACCESS_KEY"]

    BucketNamespacePrefix = 'forforf'
    
    @@s3_connection = S3::Base.establish_connection!(:access_key_id => AccessKey,
                                                                          :secret_access_key => SecretKey,
                                                                          :persistent => false)
    
    attr_accessor :bucket_name

    def initialize(glue_env, node_key_value)
      #@s3_connection = S3::Base.establish_connection!(:access_key_id => AccessKey,
      #                                                                    :secret_access_key => SecretKey)
      @bucket_name = "#{BucketNamespacePrefix}_#{glue_env.user_datastore_location}"
      #@attachment_bucket = use_bucket(@bucket_name)  #This can be stale!!!
      #verify bucket is ready
      #puts "Previous Response: #{S3::Service.response}"
      #puts "#{__LINE__} - #{ S3::Service.buckets(true).map{|b| b.name} }"
      #puts "This Bucket: #{@attachment_bucket.name}"
      #puts "Last Response: #{S3::Service.response}"
      #size = @attachment_bucket.size
    end

    #TODO: Move common file management functions from base node to here
    def add(node, file_datas)
      filenames = []
      file_datas.each do |file_data|
        filenames << file_data[:src_filename]
      end

      filenames.each do |filename|
        basename = File.basename(filename)
        esc_basename = BufsEscape.escape(basename)
        begin
          S3::S3Object.store(esc_basename, open(filename), @bucket_name)
        rescue AWS::S3::NoSuchBucket
          puts "Rescued while adding files, retrying"
          retry_request { S3::S3Object.store(esc_basename, open(filename), @bucket_name) }
        end
      end
      #verify files are there
      files = self.list_attachments
    
      filenames.each do |f|
        bname = BufsEscape.escape(File.basename(f))
        esc_bname = BufsEscape.escape(bname)
        retry_request { S3::S3Object.store(esc_bname, open(f), @bucket_name) } unless files.include?(esc_bname)
      end
      
      #update the metadata (have to wait until they're uploaded *sigh*
      filenames.each do |f|
        basename = File.basename(f)
        attach_name = BufsEscape.escape(basename)
        begin
          s3_obj = S3::S3Object.find(attach_name, @bucket_name)
        rescue AWS::S3::NoSuchBucket
          puts "Rescued while finding bucket, retrying"
          retry_request { S3::S3Object.find(attach_name, @bucket_name) }
        end  
        modified_at = File.mtime(f).to_s
        s3_obj.metadata[:modified_at] = modified_at
        s3_obj.store
      end
      
      filenames.map {|f| BufsEscape.escape(File.basename(f))} #return basenames
    end

    def add_raw_data(node, file_name, content_type, raw_data, file_modified_at = nil)
      
      attach_name = BufsEscape.escape(file_name)
      
      options = {:content_type => content_type}
#=begin
      begin
        resp = S3::S3Object.store(attach_name, raw_data, @bucket_name, options)
      rescue AWS::S3::NoSuchBucket
        puts "Rescued while adding raw data, retrying"
        retry_request { S3::S3Object.store(attach_name, raw_data, @bucket_name, options) }
      end

        obj = S3::S3Object.find(attach_name, @bucket_name)
        obj.metadata[:modified_at] = "2011-01-13" #CGI.escape(file_modified_at)
        obj.store

      #verify files are there
      max_wait_time = 20
      now = Time.now
      until (S3::S3Object.exists?(attach_name, @bucket_name) ) || (Time.now > (now + max_wait_time))
        puts "Retrying store for add raw data"
        sleep 2
        S3::S3Object.store(attach_name, raw_data, @bucket_name, options)
      end
      
      [attach_name]
    end
    
    def list(node)
      #conforming to base file mgr
      list_attachments
    end
    
    def subtract(node, file_basenames)
      #conforming to base file mgr
      subtract_files(node, file_basenames)
    end
    
    def subtract_files(node, file_basenames)
      if file_basenames == :all
        subtract_all
      else
        subtract_some(file_basenames)
      end
    end

    def get_raw_data(node, basename)
      rtn = nil
      
      attach_name = BufsEscape.escape(basename)

      begin
        rtn = S3::S3Object.value(attach_name, @bucket_name)
      rescue AWS::S3::NoSuchBucket
        puts "Rescued while getting raw data, bucket name: #{@bucket_name}"
        begin
          rtn = retry_request(attach_name, @bucket_name){|obj, buck| puts "sdbs3: #{obj.inspect} - #{buck.inspect}"; S3::S3Object.value(obj, buck)}
        rescue AWS::S3::NoSuchKey
          rtn = nil
        end
      rescue AWS::S3::NoSuchKey
        rtn = nil
      end
      rtn
    end

    #todo change name to get_files_metadata
    def get_attachments_metadata(node)
      files_md = {}
      begin
        this_bucket = use_bucket(@bucket_name)
        objects = this_bucket.objects
      rescue  AWS::S3::NoSuchBucket
        puts "rescued while getting objects from bucket to check metadata"
        objects = retry_request{ this_bucket.objects }
      end
      objects.each do |object|
        begin
          obj_md = object.about.merge(object.metadata)
        rescue AWS::S3::NoSuchBucket 
          puts "Rescued while getting metadata from object"
          obj_md = retry_request{object.about}
        end
        time_str = obj_md["x-amz-meta-modified-at"]||Time.parse(obj_md["last_modified"]).to_s
        obj_md_file_modified = time_str
        obj_md_content_type = obj_md["content-type"]
        new_md = {:content_type => obj_md_content_type, :file_modified => obj_md_file_modified}

        new_md.merge(obj_md)  #where does the original metadata go?
        files_md[object.key] = new_md
      end
      files_md
    end#def
    
    def list_objects
      list = nil
      this_bucket = use_bucket(@bucket_name)
      begin
        list = this_bucket.objects
      rescue AWS::S3::NoSuchBucket
        puts "Rescued while listing attachments"
        list = retry_request{this_bucket.objects}
      end
      list
    end
    
    def list_attachments
      objs = list_objects
      atts = objs.map{|o| o.key} if objs
      atts || []
    end
    
    def destroy_file_container
      this_bucket = use_bucket(@bucket_name)
      begin
        this_bucket.delete(:force => true)
      rescue AWS::S3::NoSuchBucket
        puts "Running sanity check"
        buckets = S3::Service.buckets(true).map{|b| b.name}
        if buckets.include?(@bucket_name)
          puts "AWS temporarily lost bucket before finding it so it can be deleted"
          retry_request { this_bucket.delete(:force => true) }
        end
      end
    end
    
    def subtract_some(file_basenames)
      file_basenames.each do |basename|
        attach_name = BufsEscape.escape(basename)
        S3::S3Object.delete(attach_name, @bucket_name)
      end
    end
    
    def subtract_all
      #Changed behavior to leave bucket (this is different than other FileMgrs) 
      this_bucket = use_bucket(@bucket_name)
      begin  
        this_bucket.delete_all
      rescue AWS::S3::NoSuchBucket
        puts "Bucket not found while deleting all. Maybe it's already been deleted?"
        return nil
        #aws_names = retry_request{@attachment_bucket.objects}
      end
      
      max_wait_time = 20
      now = Time.now
      
      while Time.now < (now + max_wait_time)
        begin
          this_bucket.delete
        rescue AWS::S3::BucketNotEmpty
          sleep 1
          puts "Bucket not empty yet, trying again"
          this_bucket.delete_all
          next
        end
        break
      end
      
      use_bucket(@bucket_name)
      #file_basenames = aws_names.map{|o| o.key} if aws_names
      #self.subtract_some(file_basenames) if file_basenames
    end
  
    def retry_request(*args, &block)
      puts "RETRYING Request with block: #{block.inspect}"
      wait_time = 2
      backoff_delay = 0.5
      max_retries = 10
      
      resp = nil

      1.upto(max_retries) do |i|
        puts "Wating #{wait_time} secs to try again"
        sleep wait_time
        begin
          resp = yield *args
          raise TypeError, "Response was Nil, retrying" unless resp
          break
        rescue AWS::S3::NoSuchKey => e
          raise e  #we want to raise this one"
        rescue AWS::S3::ResponseError => e 
          puts "rescued #{e.inspect}"
          backoff_delay += backoff_delay# * i
          wait_time += backoff_delay
          if (wait_time > 3) && (e.class == AWS::S3::NoSuchBucket)
            puts "Attempting to reset bucket"
            @attachment_bucket = use_bucket(@bucket_name)
          end
          next
        end#begin-rescue
      end#upto
      
      
    end#def
    
    def use_bucket(bucket_name)
      begin
        bucket = S3::Bucket.find(bucket_name)
      rescue (AWS::S3::NoSuchBucket||NilBucketError) => e
        begin
          puts "Rescued error in use_bucket: #{e.inspect}"
          S3::Bucket.create(bucket_name)
          bucket = S3::Bucket.find(bucket_name)
        rescue AWS::S3::NoSuchBucket #we just made it!!
          bucket = retry_request(bucket_name){|buck_name| S3::Bucket.find(buck_name)}
        end#inner begin-rescue
      end#outer begin-rescue
      
      #verify bucket exists
      found_buckets = S3::Service.buckets(true).map{|b| b.name}
      unless found_buckets.include?(bucket_name)
        #bucket = retry(:retry_block, bucket_name){|buck_name| S3::Bucket.find(buck_name)}
      end#unless
      unless bucket
        puts "NIL Bucket cannot be returned"
        retry_request(bucket_name){|buck_name| S3::Bucket.find(buck_name)}
      end
      raise(NilBucketError, "NIL Bucket cannot be returned",nil) unless bucket
      return bucket
    end#def
    
  end#class
end#module