require 'redguide/cli/base'

module Redguide
  module CLI
    class Changeset < Redguide::CLI::Base
      desc 'list', 'Determines if a piece of food is gross or delicious'
      option :project, type: :string, default: config['project'], required: true

      def list
        client.project(options[:project]).changesets.each do |changeset|
          puts " - #{changeset.key} (#{changeset.description})"
        end
      end


      desc 'show CHANGESET_KEY', 'Determines if a piece of food is gross or delicious'
      option :project, :type => :string, default: config['project'], required: true
      def show(key)
        changeset = client.project(options[:project]).changeset(key)
        puts "\n== #{changeset.key}\n\n#{changeset.description}\n\n"
        puts "=== Cookbooks\n\n"
        status_format = "%20s | %10s | %10s | %10s | %10s | %10s\n"
        printf status_format, 'Cookbook', 'Overall', 'FoodCritic', 'CookStyle', 'RSpec', 'Kitchen'
        puts '-' * 90
        changeset.cookbook_builds.each do |cookbook|
          printf status_format,
                 cookbook.name,
                 Redguide::API::STATUS_MSG[cookbook.status],
                 Redguide::API::STATUS_MSG[cookbook.status(:foodcritic)],
                 Redguide::API::STATUS_MSG[cookbook.status(:cookstyle)],
                 Redguide::API::STATUS_MSG[cookbook.status(:rspec)],
                 Redguide::API::STATUS_MSG[cookbook.status(:kitchen)]
        end
        puts '-' * 90
      end


      desc 'create KEY DESCRIPTION', 'Determines if a piece of food is gross or delicious'
      option :project, :type => :string, default: config['project'], required: true
      def create(key, description)
        changeset = client.project(options[:project]).create_changeset(key, description)

        config = {
            key: changeset.slug,
            project: changeset.project.slug,
            server: Redguide::API::server
        }
        directory('changeset', "./#{key}", config)

        say "New changeset created: #{changeset.url}", :green
      end

    end
  end
end