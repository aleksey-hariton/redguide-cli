require 'redguide/cli/base'
require 'git'

module Redguide
  module CLI
    class Cookbook < Base

      desc 'list', 'List project cookbooks'
      option :project, :type => :string, default: config['project'], required: true
      def list
        client.project(options[:project]).cookbooks.each do |cookbook|
          puts " - #{cookbook.name} (#{cookbook.vcs_url})"
        end
      end

      desc 'show COKBOOK', 'Show cookbook info'
      option :project, :type => :string, default: config['project'], required: true
      def show(name)
        cookbook = client.project(options[:project]).cookbook(name)
        puts "=====\n\n #{cookbook.name}\n\n=====\n\n#{cookbook.vcs_url}"
      end

      desc 'add PATH', 'Add cookbook to RedGuide'
      option :project, :type => :string, default: config['project'], required: true
      def add(path)
        git = Git.open(path)
        vcs_url = git.remotes.first.url
        name = File.basename(path)
        cookbook = client.project(options[:project]).create_cookbooks(name, vcs_url)
        puts "=====\n\n #{cookbook.name}\n\n=====\n\n#{cookbook.vcs_url}"
      end
    end
  end
end