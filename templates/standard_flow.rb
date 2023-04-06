#!/usr/bin/env ruby

require 'gem/release'

require 'tty/prompt'

pmt = TTY::Prompt.new

pmt.puts "\n Standard GEM release flow version #{Release::Gem::VERSION}\n".yellow

begin

  Release::Gem.engine(:gem, root: Dir.getwd, ui: STDOUT) do

    # step 1 : run test
    run_test(:rspec) 

    gem_action do

      # step 2 : check dependency
      release_dependencies

      # step 3 : build the gem
      st, ver = build do |ops, *args|
        case ops
        when :action_start
          pmt.say " Gem building starting...\n".yellow
        when :select_version
          opts = args.first
          res = pmt.select("\n Please select new gem version : \n".yellow) do |m|
            opts[:proposed_next].reverse.each do |v|
              m.choice v,v
            end
            m.choice "#{opts[:current_version]} -> Current version ", opts[:current_version]
            m.choice "Custom version", :custom
            m.choice "Abort", :abort
          end

          raise Release::Gem::Abort, "Abort by user" if res == :abort

          if res == :custom
            loop do
              res = pmt.ask("\n Please provide custom version number for the release : ".yellow,required: true)
              proceed = pmt.yes?("\n Use version '#{res}'? No to try again")
              break if proceed
            end
          end

          res

        when :multiple_version_files_found
          res = pmt.select("\n There are multiple version file found. Please select which one to update : ".yellow) do |m|
            opts = args.first
            opts.each do |f|
              m.choice f,f
            end
            m.choice "Abort", :abort
          end

          raise Release::Gem::Abort, "Abort by user" if res == :abort
          res
        when :new_version_number
          @selVersion = args.first

        when :gem_build_successfully
          pmt.puts "\n Gem version '#{args.first}' built successfully".green
          register(:selected_version, args.first)

        end
      end

      if st

        # step 4, push the gem to rubygems
        push(version: @selVer) do |ops, *args|
          case ops
          when :multiple_rubygems_account
            creds = args.first
            res = pmt.select("\n Multiple rubygems account detected. Please select one : ".yellow) do |m|
              creds.each do |k,v|
                m.choice k,k
              end
              m.choice "Skip gem push", :skip
              m.choice "Abort", :abort
            end

            raise Release::Gem::Abort, "Abort by user" if res == :abort
            res
          end
        end

        # step 5: install gem into system
        sysInst = pmt.yes?("\n Install release into system? ".yellow)
        if sysInst
          install(version: @selVer)
        end

      end

    end # gem_action

    vcs_action do
      @selVer = value(:selected_version)

      # step 6 : commit vcs
      res = commit do |ops, *args|
        case ops
        when :select_files_to_commit
          mfiles = args.first
          pmt.puts "\n Files already added to staging : ".yellow
          mfiles[:staged].each do |k,v|
            v.each do |vv|
              pmt.puts " * #{vv}"
            end
          end

          pmt.puts ""

          sel = pmt.multi_select "\n Following are files that could be added to version control : ".yellow do |m|

            [:modified, :new, :deleted].each do |cat|
              mfiles[cat].each do |k,v|
                v.each do |vv|
                  m.choice vv, vv.path
                end
              end

            end

            m.choice "Skip", :skip if mfiles[:counter] == 0
            m.choice "Done", :done
            m.choice "Abort", :abort
          end

          if sel.include?(:abort)
            raise Release::Gem::Abort, "User aborted"
          elsif sel.include?(:skip)
            :skip 
          else
            res = :done if sel.include?(:done)
            s = sel.clone
            s.delete_if { |e| e == :done }
            if not_empty?(s)
              st, cres = add_to_staging(*s) if not_empty?(s)
              if st
                pmt.puts "\n Files added successfully".green
              else
                pmt.puts "\n Files failed to be added. Message was : #{cres}".red
              end
            end

            res
          end

        when :commit_message
          msg = ""
          loop do
            msg = pmt.ask("\n Commit message : ".yellow, required: true)
            confirm = pmt.yes?(" Commit message : #{msg}\n Proceed? No to provide a new commit message ".yellow)
            if confirm
              break
            end
          end
          msg

        when :staged_elements_of_commit
          elements = args.first
          pmt.puts "\n Following files/directories shall be committed in this session : ".yellow
          elements.each do |k,v|
            v.each do |vv|
              pmt.puts " * #{vv}"
            end
          end

        when :commit_successful
          pmt.puts "\n Changes committed".green

        when :commit_failed
          pmt.puts "\n Changes failed to be committed. Error was : #{args.first}"

        end
      end # commit

      # step 7 : tag the source code
      # if the top of the changes is not tagged, means there are changes after last tagged
      tag({ tag: @selVer }) do |ops, *args|
        case ops
        when :tag_message
          pmt.ask("\n Please provide message for the tag : ".yellow, value: "Auto tagging by gem-release gem during releasing version #{@selVer}", required: true)
        when :tagging_success
          pmt.puts "\n Tagging of source code is successful.".green

        when :tagging_failed
          pmt.puts "\n Tagging of source code failed. Error was : #{args.first}".red

        when :no_tagging_required
          pmt.puts "\n No tagging required. Source head is the tagged item ".green

        end
      end

      
      push do |ops, *args|
        case ops
        when :select_remote
          val = args.first
          sel = pmt.select("\n Please select one of the remote config below : ") do |m|
            val.each do |k,v|
              m.choice k, k
            end
            m.choice "Skip pushing source code", :skip
            m.choice "Abort", :abort
          end
          raise Release::Gem::Abort, "User aborted" if sel == :abort
          sel

        when :no_remote_repos_defined
          add = pmt.yes?("\n No remote configuration defined. Add one now?")
          if add
            name = pmt.ask("\n Name of the repository : ", value: "origin", required: true)
            url = pmt.ask("\n URL of the repository : ", required: true)

            st, res = add_remote(name, url)
            if st
              pmt.puts "\n Remote configuration added successfully".green
              name
            else
              raise Release::Gem::Abort, "Failed to add remote configuration. Error was : #{res}"
            end
          end

        when :push_successful
          pmt.puts "\n Push success!".green

        when :push_failed
          pmt.puts "\nPush failed. Error was : #{args.first}".red

        when :no_changes_to_push
          val = args.first
          pmt.puts "\n Local is in sync with remote (#{val[:remote]}/#{val[:branch]}). Push is not required. "
        end

      end

    end # vcs_action block

  end # Release::Gem::Engine block

  pmt.puts "\n *** GEM standard release flow done!\n".green

rescue Release::Gem::Abort => ex
  pmt.puts "\n -- Aborted by user. Message was : #{ex.message}\n".red
rescue TTY::Reader::InputInterrupt => ex
rescue Exception => ex
  pmt.puts "\n -- Error thrown. Message was : #{ex.message}".red
end




