

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

        def manage_workspace(*args, &block)
         
          loop do

            ops = @prmt.select(pmsg("\n Please select a VCS workspace operation : ")) do |m|

              m.choice "Add", :add
              m.choice "Ignore", :ignore
              m.choice "Diff", :diff
              m.choice "Remove staged file", :remove_staged
              m.choice "Delete file", :del
              m.choice "Commit", :commit
              m.choice "Done", :done
              m.choice "Abort", :abort

            end

            case ops
            when :abort
              raise Release::Gem::Abort, "User aborted"
            when :add
              add
            when :diff
              diff
            when :ignore
              ignore
            when :remove_staged
              remove_staged
            when :del
              delete_file
            when :commit
              commit
              break
            when :done
              break
            end

          end

        end

        def add(*input, &block)
          @inst.add do |ops, *args|
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
              when :select_files_to_add

                mfiles = args.first
                @prmt.puts pmsg("\n Files already added to staging : ")
                mfiles[:staged].each do |k,v|
                  v.each do |vv|
                    @prmt.puts " * #{vv}"
                  end
                end

                @prmt.puts ""
                res = []
                [:modified, :new, :deleted].each do |cat|
                  mfiles[cat].each do |k,v|
                    v.each do |vv|
                      res << vv 
                    end
                  end
                end

                sel = @prmt.multi_select pmsg("\n Following are files that could be added to version control : ") do |m|

                  res.sort.each do |f|
                    m.choice f, f.path
                  end

                  m.choice "Done", :done
                  m.choice "Abort", :abort
                end

                if sel.include?(:abort)
                  raise Release::Gem::Abort, "User aborted"
                else
                  sel
                end

              when :files_added_successfully
                v = args.first
                @prmt.puts "\n #{v[:count]} file(s) added successfully.\n#{v[:output]}"

              when :files_failed_to_be_added
                v = args.first
                @prmt.puts "\n File(s) failed to be added. Error was : \n#{v[:output]}"

              end

            end

          end # block of add()
        end

        def diff(*input, &block)
          @inst.diff do |ops, *args|
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
              when :select_files_to_diff

                mfiles = args.first
                res = []
                [:modified, :staged].each do |cat|
                  mfiles[cat].each do |k,v|
                    v.each do |vv|
                      res << vv 
                    end
                  end
                end

                sel = @prmt.multi_select pmsg("\n Select files for diff operation : ") do |m|

                  res.sort.each do |f|
                    m.choice f, f.path
                  end

                  m.choice "Done", :done
                  m.choice "Abort", :abort
                end

                if sel.include?(:abort)
                  raise Release::Gem::Abort, "User aborted"
                else
                  sel
                end

              when :diff_file_result
                v = args.first
                @prmt.puts "Diff result for file '#{v[:file]}'"
                puts v[:output].light_blue
                STDIN.gets

              when :diff_file_error
                v = args.first
                @prmt.puts "\n Failed to diff file '#{v[:file]}'. Error was : \n#{v[:output]}"

              end

            end

          end # block of add()
        end

        def ignore(*input, &block)
          @inst.ignore do |ops, *args|
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
              when :select_files_to_ignore

                mfiles = args.first
                sel = @prmt.multi_select pmsg("\n Following are files that could be ignored : ") do |m|

                  mfiles[:files].sort.each do |v|
                    m.choice v, v.path
                  end


                  m.choice "Done", :done
                  m.choice "Abort", :abort
                end

                if sel.include?(:abort)
                  raise Release::Gem::Abort, "User aborted"
                else
                  sel
                end

              when :files_ignored_successfully
                v = args.first
                @prmt.puts "\n #{v[:count]} file(s) ignored successfully.\n#{v[:output]}"

              when :files_failed_to_be_ignored
                v = args.first
                @prmt.puts "\n File(s) failed to be ignored. Error was : \n#{v[:output]}"

              end

            end

          end # block of add()
        end

        def remove_staged(*input, &block)
          @inst.remove_from_staging do |ops, *args|
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
              when :select_files_to_remove

                mfiles = args.first

                sel = @prmt.multi_select pmsg("\n Following are files that could be removed from staging : ") do |m|

                  mfiles[:files].sort.each do |v|
                    m.choice v, v.path
                  end


                  m.choice "Done", :done
                  m.choice "Abort", :abort
                end

                if sel.include?(:abort)
                  raise Release::Gem::Abort, "User aborted"
                else
                  sel
                end

              when :files_removed_successfully
                v = args.first
                @prmt.puts "\n #{v[:count]} file(s) removed successfully.\n#{v[:output]}"

              when :files_removed_to_be_ignored
                v = args.first
                @prmt.puts "\n File(s) failed to be removed. Error was : \n#{v[:output]}"

              end

            end

          end # block
        end

        def delete_file(*args, &block)
          res = @inst.delete_file do |ops, *args|
            
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
              when :select_files_to_delete
                mfiles = args.first

                files = []
                [:new, :staged, :modified].each do |cat|
                  mfiles[cat].each do |k,v|
                    v.each do |vv|
                      files << vv
                      #m.choice vv, vv
                    end
                  end

                end


                sel = @prmt.multi_select pmsg("\n Following are files that could be deleted : ") do |m|
                  files.sort do |f|
                    m.choice f, f
                  end
                  m.choice "Done", :done
                  m.choice "Abort", :abort
                end


                if sel.include?(:abort)
                  raise Release::Gem::Abort, "User aborted"
                else
                  sel
                end

              when :confirm_nontrack_delete
                v = args.first
                @prmt.yes?(pmsg("\n Delete non-tracked file '#{v}'? "))

              when :nontrack_file_deleted
                v = args.first
                @prmt.puts pmsg("\n Non tracked file '#{v}' deleted ")

              when :confirm_vcs_delete
                v = args.first
                not @prmt.no?(pmsg("\n Delete version-controlled file '#{v}'?\n After delete the file will no longer keeping track of changes. "))

              when :vcs_file_deleted
                v = args.first
                @prmt.puts pmsg("\n Version-controlled file '#{v}' deleted ")

              when :confirm_staged_delete
                v = args.first
                @prmt.yes?(pmsg("\n Delete staged file '#{v}'?\n After delete the file shall be removed from staging. The file will still exist physically "))

              when :staged_file_deleted
                v = args.first
                @prmt.puts pmsg("\n Staged file '#{v}' deleted ")

              end
            end
          end # delete_file block

        end # delete_file



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

                files = []
                [:modified, :new, :deleted].each do |cat|
                  mfiles[cat].each do |k,v|
                    v.each do |vv|
                      files << vv
                      #m.choice vv, vv.path
                    end
                  end

                end


                sel = @prmt.multi_select pmsg("\n Following are files that could be added to version control : ") do |m|
                  
                  files.sort.each do |f|
                    m.choice f, f.path
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
                v = args.first
                @prmt.ask(pmsg("\n Please provide message for the tag : "), value: "Auto tagging by gem-release gem during releasing version #{v[:tag]}", required: true)

              when :tagging_success
                v = args.first
                @prmt.puts pmsg("\n Tagging of source code with tag '#{v[:tag]}' is successful.", :green)
                @prmt.puts v[:output]

              when :tagging_failed
                v = args.first
                @prmt.puts pmsg("\n Tagging of source code with tag '#{v[:tag]}' failed. Error was : #{v[:output]}", :red)

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
