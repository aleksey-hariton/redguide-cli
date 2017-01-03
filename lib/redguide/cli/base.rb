require 'yaml'
require 'thor'
require 'redguide/api/project'

module Redguide
  module CLI
    class Base < Thor

      RG_CONFIG_FILE = '.redguide.yml'

      include Thor::Actions
      include Thor::Shell
      include Redguide::CLI

      def self.source_root
        File.dirname(__FILE__)
      end

      attr_reader :connection
      attr_reader :config

      def initialize(*args)
        super
        if args[2][:current_command] != 'login'
          @config = self.class.config
          Redguide::API::server = @config['server']
          Redguide::API::uid = @config['user']
          Redguide::API::password = config['password']
        else
          unless File.exists?(File.join(ENV['HOME'], RG_CONFIG_FILE))
            abort "ERROR: RedGuide config not found at '#{main_config}', please run 'redguide login' first"
          end
        end

      end

      def self.config
        @@config ||= load_config
      end


      # Methods, not commands
      no_commands do
        def client
          @client ||= Redguide::API::Client.new
        end
      end

      private
        def self.load_config
          main_config = File.join(ENV['HOME'], RG_CONFIG_FILE)

          @@config = File.exists?(main_config) ? YAML.load_file(main_config) : {}
        end
    end
  end
end