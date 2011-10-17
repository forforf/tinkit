#!/usr/bin/ruby
#pw: my normal pw
#require 'rubygems'
require 'mysql'
#gem 'mysql'
#gem 'dbi'
require 'dbi'

  begin
    dbh = DBI.connect "DBI:Mysql:tinkit_spec_dummy:ec2-107-20-64-85.compute-1.amazonaws.com", "joha", "joha"
  # get server version string and display it
     row = dbh.select_one("SELECT VERSION()")
     puts "Server version: " + row[0]
   rescue DBI::DatabaseError => e
     puts "An error occurred"
     puts "Error code: #{e.err}"
     puts "Error message: #{e.errstr}"
   ensure
     # disconnect from server
     dbh.disconnect if dbh
   end

