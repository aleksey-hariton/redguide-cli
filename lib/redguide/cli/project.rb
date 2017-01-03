module Redguide
  module CLI
    class Project < Base

      desc 'list', 'Determines if a piece of food is gross or delicious'
      def list
        client.projects.each do |p|
          puts "=== #{p.key}\n\n"
          puts "#{p.description}"
        end
      end

      desc 'show PROJECT_KEY', 'Determines if a piece of food is gross or delicious'
      def show(key)
        project = client.project(key)
        puts "=====\n\n #{project.key}\n\n=====\n\n#{project.description}"
      rescue RestClient::ResourceNotFound
        puts "ERROR: project with key '#{key}' not found"
      rescue RestClient::Exception => e
        puts "ERROR: something went wrong: #{e.message}"
      end


    end
  end
end