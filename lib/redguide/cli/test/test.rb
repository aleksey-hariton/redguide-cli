require 'redguide/cli/version'
require 'redguide/cli/console'
require 'thor'

module Redguide
  module CLI
    module Test

      def self.foodcritic
        excludes = ['', 'test/', 'spec/', 'features/']
        system("foodcritic --progress --no-context --epic-fail any #{excludes.join(' --exclude ')} .") ? Redguide::API::STATUS_OK : Redguide::API::STATUS_NOK
      end

      def self.cookstyle
        system('cookstyle .') ? Redguide::API::STATUS_OK : Redguide::API::STATUS_NOK
      end

      def self.rspec
        if File.exists?('spec')
          system('rspec') ? Redguide::API::STATUS_OK : Redguide::API::STATUS_NOK
        else
          Redguide::API::STATUS_SKIPPED
        end
      end

      def self.kitchen
        kitchen_yml_file = '.kitchen.yml'
        if File.exists?(kitchen_yml_file)
          # Check if the cookbook has multi node testing or not and if no then start 2-step converge for proper environment preparation
          yml_config = YAML.load_file(kitchen_yml_file)
          multi_node = yml_config['provisioner']['multi_node']

          commands = []
          commands << 'kitchen converge' if multi_node
          commands << 'kitchen converge'
          commands << 'kitchen verify'

          # Run commands
          commands.each do |cmd|
            return Redguide::API::STATUS_NOK unless system(cmd)
          end

          # OK
          Redguide::API::STATUS_OK
        else
          Redguide::API::STATUS_SKIPPED
        end
      ensure
        if File.exists?('.kitchen.yml')
          system('kitchen destroy')
        end
      end

    end
  end
end
