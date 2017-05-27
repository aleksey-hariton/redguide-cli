require 'redguide/cli/base'

module Redguide
  module CLI
    class Cfg < Redguide::CLI::Base

      desc 'list', 'List project cookbooks'
      option :project, :type => :string, default: config['project'], required: true
      def list
        project = options[:project]
        puts "project = #{project}"
        client.project(project).configs.each do |config|
          puts config.name
        end
      end

      desc 'pull', 'Pull project config from the RedGuide'
      option :project, :type => :string, default: config['project'], required: true
      option :name, :type => :string, required: true
      option :file, :type => :string, required: true
      def pull
        project_name = options[:project]
        config_name = options[:name]
        output_file = options[:file]
        puts "project = #{project_name}"
        config = client.project(project_name).config(config_name)
        if config.name && config.content
          puts "Writing #{config_name} config to the file: #{output_file}"
        else
          puts "Couldn't config #{config_name} in the project #{project_name}"
        end

        File.open(output_file, 'w') { |file| file.write(config.content) }
      end
    end
  end
end