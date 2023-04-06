

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
          @color = opts[:msgColor] || :yellow
          @discardColor = opts[:discardColor] || false
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def overview_changes(*args, &block)
          @inst.overview_changes do |ops, *args|
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
              when :select_files_to_manage
                mfiles = args.first

                sel = @prmt.select pmsg("\n Following are files that could be managed : ") do |m|

                  [:staged, :modified, :new, :deleted].each do |cat|
                    mfiles[cat].each do |k,v|
                      v.each do |vv|
                        m.choice vv, vv
                      end
                    end

                  end

                  m.choice "Done", :done

                end

                if sel != :done

                  selOps = @prmt.select pmsg("\n What do you want to do with file '#{sel}'?") do |m|

                    m.choice "Diff", :diff 
                    m.choice "Ignore", :ignore
                    m.choice "Remove from staging", :remove_from_staging if sel.is_a?(GitCli::Delta::StagedFile)
                    m.choice "Done", :done
                  end

                  case selOps
                  when :diff
                    puts @inst.diff_file(sel.path)
                    STDIN.getc
                  when :ignore
                    confirm = @prmt.yes?(pmsg("\n Add file '#{sel.path}' to gitignore file?"))
                    if confirm
                      @inst.ignore(sel.path)
                    end
                  when :remove_from_staging
                    confirm = @prmt.yes?(pmsg("\n Remove file '#{sel.path}' from staging?"))
                    if confirm
                      @inst.remove_from_staging(sel.path)
                    end
                  when :done
                  end

                end

                sel

              end
            end

          end
        end # overview_changes

        def commit_new_files(*args, &block)
          res = @inst.commit_new_files do |ops, *args|
            
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
                @prmt.puts pmsg("\n Files already added to staging : ")
                mfiles[:staged].each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

                @prmt.puts ""

                sel = @prmt.multi_select pmsg("\n Following are new files that could be added to version control : ") do |m|

                  mfiles[:new].each do |k,v|
                    v.each do |vv|
                      m.choice vv, vv.path
                    end
                  end

                  m.choice "Skip", :skip #if mfiles[:counter] == 0
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
                      @prmt.puts pmsg("\n Files added successfully", :green)
                    else
                      @prmt.puts pmsg("\n Files failed to be added. Message was : #{cres}", :red)
                    end
                  end

                  res

                end

              when :commit_message
                msg = ""
                loop do
                  msg = @prmt.ask(pmsg("\n Commit message : "), required: true)
                  confirm = @prmt.yes?(pmsg(" Commit message : #{msg}\n Proceed? No to provide a new commit message "))
                  if confirm
                    break
                  end
                end

                msg

              when :staged_elements_of_commit

                elements = args.first
                @prmt.puts pmsg("\n Following new files/directories shall be committed in this session : ")
                elements.each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

              when :commit_successful
                @prmt.puts pmsg("\n Changes committed",:green)
                @prmt.puts args.first

              when :commit_failed
                @prmt.puts pmsg("\n Changes failed to be committed. Error was : #{args.first}")

              end
            end
          end # commit_new_files block

        end # commit_new_files


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
                @prmt.puts pmsg("\n Files already added to staging : ")
                mfiles[:staged].each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

                @prmt.puts ""

                sel = @prmt.multi_select pmsg("\n Following are files that could be added to version control : ") do |m|

                  [:modified, :new, :deleted].each do |cat|
                    mfiles[cat].each do |k,v|
                      v.each do |vv|
                        m.choice vv, vv.path
                      end
                    end

                  end

                  m.choice "Skip", :skip #if mfiles[:counter] == 0
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
                      @prmt.puts pmsg("\n Files added successfully", :green)
                    else
                      @prmt.puts pmsg("\n Files failed to be added. Message was : #{cres}", :red)
                    end
                  end

                  res

                end

              when :commit_message
                msg = ""
                loop do
                  msg = @prmt.ask(pmsg("\n Commit message : "), required: true)
                  confirm = @prmt.yes?(pmsg(" Commit message : #{msg}\n Proceed? No to provide a new commit message "))
                  if confirm
                    break
                  end
                end

                msg

              when :staged_elements_of_commit

                elements = args.first
                @prmt.puts pmsg("\n Following files/directories shall be committed in this session : ")
                elements.each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

              when :commit_successful
                @prmt.puts pmsg("\n Changes committed",:green)
                @prmt.puts args.first

              when :commit_failed
                @prmt.puts pmsg("\n Changes failed to be committed. Error was : #{args.first}")

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
                @prmt.ask(pmsg("\n Please provide message for the tag : "), value: "Auto tagging by gem-release gem during releasing version #{@selVer}", required: true)

              when :tagging_success
                @prmt.puts pmsg("\n Tagging of source code is successful.", :green)
                @prmt.puts args.first

              when :tagging_failed
                @prmt.puts pmsg("\n Tagging of source code failed. Error was : #{args.first}", :red)

              when :no_tagging_required
                @prmt.puts pmsg("\n No tagging required. Source head is the tagged item ", :green)

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
                sel = @prmt.select(pmsg("\n Please select one of the remote config below : ")) do |m|
                  val.each do |k,v|
                    m.choice k, k
                  end
                  m.choice "Skip pushing source code", :skip
                  m.choice "Abort", :abort
                end
                raise Release::Gem::Abort, "User aborted" if sel == :abort

                sel

              when :no_remote_repos_defined
                add = @prmt.yes?(pmsg("\n No remote configuration defined. Add one now?"))
                if add
                  name = @prmt.ask(pmsg("\n Name of the repository : "), value: "origin", required: true)
                  url = @prmt.ask(pmsg(" URL of the repository : "), required: true)

                  st, res = add_remote(name, url)
                  if st
                    @prmt.puts pmsg("\n Remote configuration added successfully",:green)
                    name
                  else
                    raise Release::Gem::Abort, "Failed to add remote configuration. Error was : #{res}"
                  end
                end

              when :push_successful
                @prmt.puts pmsg("\n Push success!",:green)
                @prmt.puts args.first

              when :push_failed
                @prmt.puts pmsg("\nPush failed. Error was : #{args.first}",:red)

              when :no_changes_to_push
                val = args.first
                @prmt.puts pmsg("\n Local is in sync with remote (#{val[:remote]}/#{val[:branch]}). Push is not required. ")
              end
            end

          end

        end # push

        def method_missing(mtd, *args, &block)
          @inst.send(mtd, *args, &block)
        end

        def pmsg(msg, color = nil)
          if not msg.nil?
            if @discardColor == true
              msg
            else
              if not_empty?(color)
                msg.send(color)
              elsif not_empty?(@msgColor)
                msg.send(@msgColor)
              else
                msg
              end
            end
          end
        end

      end
    end
  end
end
