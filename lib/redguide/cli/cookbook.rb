require 'redguide/cli/base'

module Redguide
  module CLI
    class Cookbook < Redguide::CLI::Base
      def self.source_root
        File.dirname(__FILE__)
      end

      desc 'list', 'List project cookbooks'
      option :project, :type => :string, default: config['project'], required: true
      def list
        connection.get("projects/#{options[:project]}/cookbooks").each do |cookbook|
          puts " - #{cookbook['name']} (#{cookbook['vcs_url']})"
        end
      end

      desc 'show CHANGESET_KEY', 'Determines if a piece of food is gross or delicious'
      option :project, :type => :string, default: config['project'], required: true
      def show(name)
        cookbook = connection.get("projects/#{options[:project]}/cookbooks/#{name}")
        puts "=====\n\n #{cookbook['name']}\n\n=====\n\n#{cookbook['vcs_url']}"
      end
    end
  end
end