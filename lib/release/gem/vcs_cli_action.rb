

require 'tty/prompt'
require_relative 'vcs_action'

module Release
  module Gem
    module Cli
      class VcsAction
        def initialize(root, opts = {  })
          opts = {} if opts.nil?
          opts[:ui] = TTY::Prompt.new
          @inst = Action::VcsAction.new(root,opts)
          @prmt = TTY::Prompt.new
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def commit(*args, &block)
          res = @inst.commit do |ops, *args|
            
            preset = false
            if block
              res = block.call(ops, *args)
              if res.nil?
                preset = true
              else
                res
              end
            else
              preset = true
            end

            if preset

              case ops
              when :select_files_to_commit
                mfiles = args.first
                @prmt.puts "\n Files already added to staging : ".yellow
                mfiles[:staged].each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

                @prmt.puts ""

                sel = @prmt.multi_select "\n Following are files that could be added to version control : ".yellow do |m|

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
                      @prmt.puts "\n Files added successfully".green
                    else
                      @prmt.puts "\n Files failed to be added. Message was : #{cres}".red
                    end
                  end

                  res

                end

              when :commit_message
                msg = ""
                loop do
                  msg = @prmt.ask("\n Commit message : ".yellow, required: true)
                  confirm = @prmt.yes?(" Commit message : #{msg}\n Proceed? No to provide a new commit message ".yellow)
                  if confirm
                    break
                  end
                end

                msg

              when :staged_elements_of_commit

                elements = args.first
                @prmt.puts "\n Following files/directories shall be committed in this session : ".yellow
                elements.each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

              when :commit_successful
                @prmt.puts "\n Changes committed".green
                @prmt.puts args.first

              when :commit_failed
                @prmt.puts "\n Changes failed to be committed. Error was : #{args.first}"

              end
            end
          end # commit

        end # Commit

        def tag(*args, &block)
        
          @inst.tag(*args) do |ops, *args|

            preset = false
            if block
              res = block.call(ops, *args)
              if res.nil?
                preset = true
              else
                res
              end
            else
              preset = true
            end

            if preset

              case ops
              when :tag_message
                @prmt.ask("\n Please provide message for the tag : ".yellow, value: "Auto tagging by gem-release gem during releasing version #{@selVer}", required: true)

              when :tagging_success
                @prmt.puts "\n Tagging of source code is successful.".green
                @prmt.puts args.first

              when :tagging_failed
                @prmt.puts "\n Tagging of source code failed. Error was : #{args.first}".red

              when :no_tagging_required
                @prmt.puts "\n No tagging required. Source head is the tagged item ".green

              end
            end # preset ?

          end

        end # tag

        def push(*args, &block)

          @inst.push do |ops, *args|
            preset = false
            if block
              res = block.call(ops, *args)
              if res.nil?
                preset = true
              else
                res
              end
            else
              preset = true
            end

            if preset

              case ops
              when :select_remote
                val = args.first
                sel = @prmt.select("\n Please select one of the remote config below : ") do |m|
                  val.each do |k,v|
                    m.choice k, k
                  end
                  m.choice "Skip pushing source code", :skip
                  m.choice "Abort", :abort
                end
                raise Release::Gem::Abort, "User aborted" if sel == :abort

                sel

              when :no_remote_repos_defined
                add = @prmt.yes?("\n No remote configuration defined. Add one now?")
                if add
                  name = @prmt.ask("\n Name of the repository : ", value: "origin", required: true)
                  url = @prmt.ask("\n URL of the repository : ", required: true)

                  st, res = add_remote(name, url)
                  if st
                    @prmt.puts "\n Remote configuration added successfully".green
                    name
                  else
                    raise Release::Gem::Abort, "Failed to add remote configuration. Error was : #{res}"
                  end
                end

              when :push_successful
                @prmt.puts "\n Push success!".green
                @prmt.puts args.first

              when :push_failed
                @prmt.puts "\nPush failed. Error was : #{args.first}".red

              when :no_changes_to_push
                val = args.first
                @prmt.puts "\n Local is in sync with remote (#{val[:remote]}/#{val[:branch]}). Push is not required. "
              end
            end

          end

        end # push

        def method_missing(mtd, *args, &block)
          @inst.send(mtd, *args, &block)
        end

      end
    end
  end
end
