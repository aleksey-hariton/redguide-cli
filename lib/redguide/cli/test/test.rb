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
        if File.exists?('.kitchen.yml')
          status = system('kitchen converge') && system('kitchen verify')
          status ? Redguide::API::STATUS_OK : Redguide::API::STATUS_NOK
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
