#!/usr/bin/env ruby
#
# List Filesystem Usage for every chef node that matches the hostname
# provided. If no argument is provided, matches all the nodes.
#
# Example:
# chef_node_fs_usage '*.cdn.example.com'
# (matches every node whose fqdn ends with cdn.example.com)
#
require 'rubygems'
require 'couchrest'
require 'chef'
require 'choice'
require 'pp'

CHEF_DB_URL = 'http://localhost:5984/chef'

def main
  Choice.options do
    header ''
    header 'Available options:'

    option :help do
      long '--help'
      short '-h'
      desc 'Show this message'
      action do 
        Choice.help
        exit
      end
    end

    option :usage_threshold do
      long '--usage-threshold'
      short '-t'
      desc 'Print only the filesystems with usage percent greater than this value'
    end

    option :match do 
      default '.*'
      long '--match'
      short '-m'
      desc 'Match only the nodes with an FQDN matching this value'
    end
  end

  db = CouchRest.database(CHEF_DB_URL)

  db.documents['rows'].each do |doc|
    if doc['id'] =~ /node_/
      node = db.get(doc['id'])
      next if  node.fqdn !~ /#{Choice.choices[:match]}/
      matching_fs = []
      node.filesystem.each do |fsname,fsattrs|
        if not (%w[proc binfmt_misc sysfs tmpfs devpts rpc_pipefs].include? fsattrs['fs_type'])
          if Choice.choices[:usage_threshold]
            uthres = Choice.choices[:usage_threshold].to_i
            usage = fsattrs['percent_used'].chomp.strip.gsub('%','').to_i
            (matching_fs << "    #{fsname}".ljust(50) + fsattrs['percent_used']) if usage > uthres
          else
            matching_fs << "    #{fsname}".ljust(50) + fsattrs['percent_used']
          end
        end
      end
      if not matching_fs.empty?
        puts node.fqdn
        matching_fs.each do |fs|
          puts fs
        end
        puts
      end
    end
  end

end

main
