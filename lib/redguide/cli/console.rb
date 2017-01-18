require 'redguide/cli/base'
require 'redguide/cli/project'
require 'redguide/cli/changeset'
require 'redguide/cli/cookbook'
require 'redguide/cli/test/test'
require 'redguide/api'
require 'redguide/supermarket'
require 'json'
require 'git'
require 'semver'

module Redguide
  module CLI
    class Console < Redguide::CLI::Base

      desc 'project SUBCOMMAND ...ARGS', 'Project manipulation'
      subcommand 'project', Redguide::CLI::Project

      desc 'changeset SUBCOMMAND ...ARGS', 'Changesets manipulation'
      subcommand 'changeset', Redguide::CLI::Changeset

      desc 'cookbook SUBCOMMAND ...ARGS', 'Cookbooks manipulation'
      subcommand 'cookbook', Redguide::CLI::Cookbook

      desc 'login', 'Login to RedGuide server and save config'
      option :server, type: :string, required: true
      option :user, type: :string, required: true
      option :password, type: :string, required: true
      def login
        Redguide::API::server = options[:server]
        Redguide::API::uid = options[:user]
        Redguide::API::password = options[:password]
        client

        say "====> Logged in successfully as '#{options[:user]}'", :green

        config = {
            server: options[:server],
            user: options[:user],
            password: options[:password]
        }
        directory('main_config', ENV['HOME'], config)
      end

      desc 'add COOKBOOK', 'Add cookbook to changeset'
      def add(cookbook)
        abort "ERROR: Look like current directory is not changeset, no '#{RG_CONFIG_FILE}' found" unless File.exists? RG_CONFIG_FILE

        end_conf = YAML.load_file(RG_CONFIG_FILE)
        end_conf['user'] = config['user']
        end_conf['password'] = config['password']

        changeset = client.project(end_conf['project']).changeset(end_conf['changeset'])
        changeset.add_cookbook(cookbook)

        say "==> Cookbook '#{cookbook}' added to changeset '#{changeset.key}' - #{changeset.url}", :green

        url = changeset.cookbook(cookbook)['vcs_url']
        unless File.exists?("./#{cookbook}")
          cookbook_branch = changeset.key.upcase + '_' + changeset.description.downcase.gsub(/\W/, '_')
          say "==> Cloning '#{cookbook}' from #{url}", :green
          git = Git.clone(url, cookbook)
          remote_branch = git.branches.remote.select{|b| b.name == cookbook_branch}.first
          branch_local = git.branches.local.select{|b| b.name == cookbook_branch}.first

          if remote_branch && !branch_local
            Dir.chdir("./#{cookbook}") do
              x = system("git checkout -b '#{cookbook_branch}' --track 'origin/#{cookbook_branch}'")
              abort 'Something wen wring' unless x
            end
          else
            git.branch(cookbook_branch).checkout
          end
        end
      end

      desc 'build [all|foodcritic|cookstyle|rspec|kitchen]', 'Test cookbook. Default: all'
      option :notify, type: :boolean, default: false, desc: 'Notify RedGuide about status or not'
      option :publish, type: :boolean, default: false, desc: 'Publish cookbook on Supermarket or not'
      option :local_cookbooks, type: :boolean, default: true, desc: 'Use cookbooks from local changeset. Otherwise use cookbooks from Git (RedGuide).'
      def build(what = 'all')
        notify = options[:notify]
        publish = options[:publish]
        rg_config_file = "../#{RG_CONFIG_FILE}"
        if !File.exists?(rg_config_file) && !(ENV['RG_PROJECT'] && ENV['RG_CHANGESET'])
          abort "ERROR: Look like current directory not in changeset, file '../#{RG_CONFIG_FILE}' not found"
        end

        if File.exists?(rg_config_file)
          changeset_settings = YAML.load_file(rg_config_file)
        else
          changeset_settings = {
              'project' => ENV['RG_PROJECT'],
              'changeset' => ENV['RG_CHANGESET'],
          }
        end

        cookbook_directory = Dir.pwd
        cookbook = File.basename cookbook_directory
        project_name = changeset_settings['project']

        project = client.project(project_name)
        changeset = project.changeset(changeset_settings['changeset'])

        Dir.mktmpdir do |dir|
          # Copy all files from cookbook folder, without `.kitchen` and `.git` (if not publish flag set)
          pattern = publish ? '(\A\.kitchen\/.*\z)' : '(\A\.kitchen\/.*|\.git\/.*\z)'
          directory cookbook_directory, dir, verbose: false, exclude_pattern: /#{pattern}/

          # Merge master before build, if user wants to publish cookbook
          if publish

            #### STEP 1. Merge 'master'
            #
            git = Git.open(dir)
            # changeset.merge_pr
            git.pull('origin', 'master')

            # Read metadata.rb
            metadata_path = 'metadata.rb'
            metadata = File.read(metadata_path)

            # Extract cookbook version
            version_regex = /^version\s+['"]{1}+([0-9\.]+)['"]{1}/
            version_string = metadata.match(version_regex)[0]
            version = metadata.match(version_regex)[1]

            #### STEP 2. Check Supermarket for released version
            #
            supermarket_config = project.supermarket_config
            Redguide::Supermarket::server = supermarket_config[:url]

            # Calculate new cookbook version
            v = SemVer.parse(version)
            v.patch += 1
            new_version = v.to_s.delete('v')

            super_cookbook = Redguide::Supermarket::Client.new().cookbook(cookbook)

            #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! CHECK THAT Git HAS CHANGES if DOESNT CHECK IF DOESN'T
            # DO GIT CHERRY AND CHECK IF CHANGES PUSHED?
            # IF NOT TAG AND PUSH

            if super_cookbook
              if super_cookbook.versions.include?(new_version)
                abort "ERROR: Cookbook version '#{new_version}' already released on Supermarket - '#{super_cookbook.url(new_version)}'"
              end
            else
              say "Looks like it first release of '#{cookbook}', no versions found", :blue
            end
          end
          # END publish

          statuses = {}
          success = true

          Dir.chdir dir do
            fc_config = File.join(dir, '.foodcritic')
            cs_config = File.join(dir, '.rubocop.yml')
            kitchen_config = File.join(dir, '.kitchen.yml')
            kitchen_local_config = File.join(dir, '.kitchen.local.yml')

            # Write down config files
            File.write(fc_config, project.config(:foodcritic)) unless ::File.exists?(fc_config)
            File.write(cs_config, project.config(:cookstyle)) unless ::File.exists?(cs_config)
            File.write(kitchen_local_config, project.config(:kitchen)) if ::File.exists?(kitchen_config)

            # FoodCritic
            if ['all', 'foodcritic'].include?(what)
              say "\n\n====> Starting FoodCritic...\n\n\n", :green
              changeset.notify_cookbook(cookbook, 'foodcritic', Redguide::API::STATUS_IN_PROGRESS) if notify
              statuses['FoodCritic'] = CLI::Test.foodcritic
              changeset.notify_cookbook(cookbook, 'foodcritic', statuses['FoodCritic']) if notify
            end

            # CookStyle
            if ['all', 'cookstyle'].include?(what)
              say "\n\n====> Starting CookStyle...\n\n\n", :green
              changeset.notify_cookbook(cookbook, 'cookstyle', Redguide::API::STATUS_IN_PROGRESS) if notify
              statuses['CookStyle'] = CLI::Test.cookstyle
              changeset.notify_cookbook(cookbook, 'cookstyle', statuses['CookStyle']) if notify
            end

            # RSpec, ChefSpec
            if ['all', 'rspec'].include?(what)
              say "\n\n====> Starting RSpec...\n\n\n", :green
              changeset.notify_cookbook(cookbook, 'rspec', Redguide::API::STATUS_IN_PROGRESS) if notify
              statuses['RSpec'] = CLI::Test.rspec
              say "\n\n====> No RSpec tests, skipping...\n\n\n", :cyan if statuses['RSpec'] == Redguide::API::STATUS_SKIPPED
              changeset.notify_cookbook(cookbook, 'rspec', statuses['RSpec']) if notify
            end

            # Kitchen
            if ['all', 'kitchen'].include?(what)
              say "\n\n====> Starting Kitchen...\n\n\n", :green
              changeset.notify_cookbook(cookbook, 'kitchen', Redguide::API::STATUS_IN_PROGRESS) if notify

              berksfile = File.join(dir, 'Berksfile')
              if File.exists?(berksfile)
                # Newlines
                append_to_file berksfile, "#\n#\n"
                if options[:local_cookbooks]
                  search = "#{cookbook_directory}/../*/metadata.rb"
                  cookbooks = Dir[search].map do |d|
                    {
                        name: File.basename(File.dirname(d)),
                        path: File.realpath(File.dirname(d))
                    }
                  end

                  cookbooks.each do |c|
                    next if c[:name] == cookbook
                    comment_lines berksfile, /cookbook\s+['"]#{c[:name]}['"].*/
                    append_to_file berksfile, "cookbook '#{c[:name]}', path: '#{c[:path]}'\n"
                  end
                else
                  changeset.cookbook_builds.each do |build|
                    next if build.name == cookbook
                    sha = build.commit_sha.empty? ? 'master' : build.commit_sha
                    comment_lines berksfile, /cookbook\s+['"]#{build.name}['"].*/
                    append_to_file berksfile, "cookbook '#{build.name}', git: '#{build.vcs_url}', ref: '#{sha}'\n"
                  end
                end
              end

              statuses['Kitchen'] = CLI::Test.kitchen
              say "====> No Kitchen config, skipping...\n\n\n", :cyan if statuses['Kitchen'] == Redguide::API::STATUS_SKIPPED
              changeset.notify_cookbook(cookbook, 'kitchen', statuses['Kitchen']) if notify
            end

            status_strings = {
                Redguide::API::STATUS_OK => "\e[32mOK\e[0m",
                Redguide::API::STATUS_NOK => "\e[31mFAILED\e[0m",
                Redguide::API::STATUS_SKIPPED => "\e[37mSKIPPED\e[0m"
            }

            statuses.each do |key, val|
              puts "#{key.rjust(20)} - #{status_strings[val]}"
              success = false if val == Redguide::API::STATUS_NOK
            end

            # Publish
            if publish
              if success

                if `git cherry`.empty?
                  say('No new commits found, nothing to release', :red)
                  abort
                end

                #### STEP 3. Version bump
                #
                say "Original cookbook version: '#{version}', new cookbook version: '#{new_version}'", :green
                metadata.gsub!(version_string) do |line|
                  line.gsub(version, new_version)
                end

                say 'Updating metadata.rb file', :green
                File.open(metadata_path, 'w') do |f|
                  f.write(metadata)
                end

                #### STEP 4. Generate CHANGELOG.md
                #
                if `which git-changelog`.strip.empty?
                  say "Cant find 'git-changelog', skipping CHANGELOG.md generation", :yellow
                else
                  say 'Generating CHANGELOG.md', :green
                  system("git-changelog -a -x -n -t #{new_version} -p > ./CHANGELOG.md")
                  git.add('CHANGELOG.md')
                end

                #### STEP 5. Git TAG
                #
                git.add('metadata.rb')
                say 'Commiting CHANGELOG.md and metadata.rb', :green
                git.commit("Version bump to v#{new_version}")
                # git tag
                say "Tagging to #{new_version}", :green
                commit_id = git.add_tag(new_version).sha

                #### STEP 6. PUSH
                #
                say "Git push to origin remote (commit '#{commit_id}')", :green
                # git push origin `git rev-list -n 1 $NEW_VERSION`:$DST_BRANCH
                git.push(git.remote('origin'), "#{commit_id}:master", tags: true)

                #### STEP 7. Publish to Supermarket
                #
                File.write("#{project.chef_user}.pem", project.chef_user_pem)
                system "stove --endpoint '#{Redguide::Supermarket::endpoint}' --username '#{project.chef_user}' --key './#{project.chef_user}.pem' --extended-metadata --no-git"

                abort 'THE END!'
              else
                say 'Cookbook build failed, publishing skipped', :red
              end
            end
            ## END publish
          end

          exit 1 unless success
        end
      end

      desc 'push', 'Push cookbooks to changeset'
      def push
        abort "ERROR: Look like current directory not a changeset, no '#{RG_CONFIG_FILE}' found" unless File.exists? RG_CONFIG_FILE

        end_conf = YAML.load_file(RG_CONFIG_FILE)
        cookbooks = Dir['*/.git/'].map{|d| File.dirname(d)}

        to_push = {}
        cookbooks.each do |cookbook|
          git = Git.open(cookbook)
          remote_branches = git.branches.remote.select{|b| b.name == git.current_branch}.first
          Dir.chdir(cookbook) do
            if remote_branches
                cherry = `git cherry`
                git.push('origin', git.current_branch) unless cherry.empty?
            else
              abort 'ERROR: Something went wrong' unless system("git push -u origin '#{git.current_branch}'")
            end
          end
          to_push[cookbook] = {}
          to_push[cookbook]['commit_sha'] = git.revparse('HEAD')
          to_push[cookbook]['remote_branch'] = git.current_branch
        end

        changeset = client.project(end_conf['project']).changeset(end_conf['changeset'])
        changeset.push(to_push)

        say "Pushed successfully: #{changeset.url}", :green
      end

      desc 'pull [CHANGESET]', 'Pull changeset cookbooks from RedGuide'
      def pull(key = nil)
        if key
          changeset = client.project(config['project']).changeset(key)
          config = {
              key: changeset.slug,
              project: changeset.project.slug,
              server: Redguide::API::server
          }
          directory('changeset', "./#{key}", config)
          Dir.chdir("./#{key}")
        else
          abort "ERROR: Look like current directory not a changeset, no '#{RG_CONFIG_FILE}' found" unless File.exists? RG_CONFIG_FILE
        end

        end_conf = YAML.load_file(RG_CONFIG_FILE)
        changeset ||= client.project(end_conf['project']).changeset(end_conf['changeset'])

        changeset.cookbook_builds.each do |build|
          say "===> Checking out cookbook '#{build.name}'", :green
          cookbook_folder = File.join('.', build.name)
          cookbook_branch = build.remote_branch.empty? ? changeset.key : build.remote_branch
          if File.exists?(cookbook_folder)
            git = Git.open(cookbook_folder)
            git.fetch('origin')
          else
            git = Git.clone(build.vcs_url, build.name)
          end

          remote_branch = git.branches.remote.select{|b| b.name == cookbook_branch}.first
          branch_local = git.branches.local.select{|b| b.name == cookbook_branch}.first

          if remote_branch && !branch_local
            Dir.chdir(cookbook_folder) do
              x = system("git checkout -b '#{cookbook_branch}' --track 'origin/#{cookbook_branch}'")
              abort 'Something wen wring' unless x
            end
          else
            git.branch(cookbook_branch).checkout
          end

          git.pull('origin', cookbook_branch) if remote_branch
        end
      end
    end
  end
end