
require 'gvcs'
require 'git_cli'

module Release
  module Gem
    module Action

      class VcsActionError < StandardError; end
      
      class VcsAction
        include TR::CondUtils

        attr_accessor :ui

        def initialize(root, opts = {  })
          raise VcsActionError, "root cannot be null" if is_empty?(root)
          @ws = Gvcs::Workspace.new(root) 

          oopts = opts || {}
          @ui = oopts[:ui]
          @engine = oopts[:engine]
          st, path = @ws.workspace_root

          #@gitDir = File.join(path.strip,".git")
          #p @gitDir
          #@gitBack = File.join(path.strip,".git_bak")
          #p @gitBack
        end

        #def enable_dev_mode
        #  FileUtils.cp_r(@gitDir,@gitBack, remove_destination: true)
        #end

        #def dev_mode_end
        #  if File.exist?(@gitBack)
        #    FileUtils.mv(@gitBack, @gitDir)
        #  end
        #end

        def exec(&block)
          instance_eval(&block) if block
        end

        def add(&block)
          
          if block
            
            loop do

              stgDir, stgFiles = @ws.staged_files
              modDir, modFiles = @ws.modified_files
              newDir, newFiles = @ws.new_files
              delDir, delFiles = @ws.deleted_files

              modFiles.delete_if { |f| stgFiles.include?(f) }
              modDir.delete_if { |f| stgDir.include?(f) }
              
              newFiles.delete_if { |f| stgFiles.include?(f) }
              newDir.delete_if { |f| stgDir.include?(f) }

              delFiles.delete_if { |f| stgFiles.include?(f) }
              delDir.delete_if { |f| stgDir.include?(f) }

              res = block.call(:select_files_to_add, { modified: { files: modFiles, dirs: modDir }, new: { files: newFiles, dirs: newDir }, deleted: { files: delFiles, dirs: delDir }, staged: { files: stgFiles, dirs: stgDir }, vcs: self } )

              doneTriggered = false
              sel = res.clone
              if sel.include?(:done)
                sel.delete_if { |e| e == :done }
                doneTriggered = true
              end

              if not_empty?(sel)
                st, rres = @ws.add_to_staging(*sel)
                if st
                  block.call(:files_added_successfully, { count: sel.length, output: rres })
                else
                  block.call(:files_failed_to_be_added, { output: rres } )
                end
              else
                block.call(:no_files_given)
              end

              break if doneTriggered

            end

          end

        end

        def diff(&block)
          
          if block
            
            loop do

              stgDir, stgFiles = @ws.staged_files
              modDir, modFiles = @ws.modified_files

              modFiles.delete_if { |f| stgFiles.include?(f) }
              modDir.delete_if { |f| stgDir.include?(f) }
              
              res = block.call(:select_files_to_diff, { modified: { files: modFiles, dirs: modDir },  staged: { files: stgFiles, dirs: stgDir }, vcs: self } )

              doneTriggered = false
              sel = res.clone
              if sel.include?(:done)
                sel.delete_if { |e| e == :done }
                doneTriggered = true
              end

              if not_empty?(sel)
                sel.each do |s|
                  st, rres = @ws.diff_file(s)
                  if st
                    block.call(:diff_file_result, { file: s, output: rres })
                  else
                    block.call(:diff_file_error, { file: s, output: rres } )
                  end
                end
              else
                block.call(:no_files_given)
              end

              break if doneTriggered

            end

          end

        end

        def ignore(*files, &block)
          
          if block
            
            loop do

              newDir, newFiles = @ws.new_files

              res = block.call(:select_files_to_ignore, { files: newFiles, dirs: newDir } )

              doneTriggered = false
              sel = res.clone
              if sel.include?(:done)
                sel.delete_if { |e| e == :done }
                doneTriggered = true
              end

              if not_empty?(sel)
                st, rres = @ws.ignore(*sel)
                if st
                  block.call(:files_ignored_successfully, { count: sel.length, output: rres })
                else
                  block.call(:files_failed_to_be_ignored, { output: rres } )
                end
              else
                block.call(:no_files_given)
              end

              break if doneTriggered

            end

          else

            @ws.ignore(*files) if not_empty?(files)

          end

        end

        def remove_from_staging(*files, &block)
          
          if block
            
            loop do

              stgDir, stgFiles = @ws.staged_files

              res = block.call(:select_files_to_remove, { files: stgFiles, dirs: stgDir } )

              doneTriggered = false
              sel = res.clone
              if sel.include?(:done)
                sel.delete_if { |e| e == :done }
                doneTriggered = true
              end

              if not_empty?(sel)
                st, rres = @ws.remove_from_staging(*sel)
                if st
                  block.call(:files_removed_successfully, { count: sel.length, output: rres })
                else
                  block.call(:files_removed_to_be_ignored, { output: rres } )
                end
              else
                block.call(:no_files_given)
              end

              break if doneTriggered

            end

          else

            @ws.removed_from_staging(*files) if not_empty?(files)

          end

        end

        def delete_file(*files, &block)
          
          if block
            
            loop do

              stgDir, stgFiles = @ws.staged_files
              modDir, modFiles = @ws.modified_files
              newDir, newFiles = @ws.new_files

              modFiles.delete_if { |f| stgFiles.include?(f) }
              modDir.delete_if { |f| stgDir.include?(f) }
              
              newFiles.delete_if { |f| stgFiles.include?(f) }
              newDir.delete_if { |f| stgDir.include?(f) }

              res = block.call(:select_files_to_delete, { modified: { files: modFiles, dirs: modDir }, new: { files: newFiles, dirs: newDir }, staged: { files: stgFiles, dirs: stgDir } } )

              doneTriggered = false
              sel = res.clone
              if sel.include?(:done)
                sel.delete_if { |e| e == :done }
                doneTriggered = true
              end

              if not_empty?(sel)
                staged = []
                nonTrack = []
                sel.each do |s|
                  if s.is_a?(GitCli::Delta::NewFile)
                    confirm = block.call(:confirm_nontrack_delete, s.path)
                    if confirm
                      FileUtils.rm(s.path)
                      block.call(:nontrack_file_deleted, s.path)
                    end
                  elsif s.is_a?(GitCli::Delta::ModifiedFile)
                    # not staged
                    confirm = block.call(:confirm_vcs_delete, s.path)
                    puts "vcs confirm : #{confirm}"
                    if confirm
                      @ws.remove_from_vcs(s.path)
                      block.call(:vcs_file_deleted, s.path)
                    end
                  elsif s.is_a?(GitCli::Delta::StagedFile)
                    confirm = block.call(:confirm_staged_delete, s.path)
                    if confirm
                      @ws.remove_from_staging(s.path)
                      block.call(:staged_file_deleted, s.path)
                    end
                  end
                end

              else
                block.call(:no_files_given)
              end

              break if doneTriggered

            end

          end
        end

        def commit(msg = nil, &block)

          res = :value
          if block

            counter = 0
            loop do

              stgDir, stgFiles = @ws.staged_files
              modDir, modFiles = @ws.modified_files
              newDir, newFiles = @ws.new_files
              delDir, delFiles = @ws.deleted_files

              modFiles.delete_if { |f| stgFiles.include?(f) }
              modDir.delete_if { |f| stgDir.include?(f) }
              
              newFiles.delete_if { |f| stgFiles.include?(f) }
              newDir.delete_if { |f| stgDir.include?(f) }

              delFiles.delete_if { |f| stgFiles.include?(f) }
              delDir.delete_if { |f| stgDir.include?(f) }

              # block should call vcs for add, remove, ignore and other operations
              res = block.call(:select_files_to_commit, { modified: { files: modFiles, dirs: modDir }, new: { files: newFiles, dirs: newDir }, deleted: { files: delFiles, dirs: delDir }, staged: { files: stgFiles, dirs: stgDir }, vcs: self, counter: counter } )

              break if res == :skip or res == :done

              counter += 1

            end

            if res == :done

              stgDir, stgFiles = @ws.staged_files
              block.call(:staged_elements_of_commit, { files: stgFiles, dirs: stgDir })

              msg = block.call(:commit_message) if is_empty?(msg) 
              raise VcsActionError, "Commit message is empty" if is_empty?(msg)

              cp "Commit with user message : #{msg}"
              st, res = @ws.commit(msg)
              if st
                block.call(:commit_successful, res) if block
              else
                block.call(:commit_failed, res) if block
              end
              [st, res]

            end

          else

            msg = "Auto commit all ('-am' flag) by gem-release gem" if is_empty?(msg)
            cp msg
            # changed files only without new files
            @ws.commit_all(msg)
          end

          res

        end

        def tag(*args, &block)
        
          opts = args.first || {  }
          tag = opts[:tag]
          msg = opts[:message]

          if not @ws.tag_points_at?("HEAD")

            if is_empty?(tag)
              raise VcsActionError, "tag name cannot be empty" if not block
              tag = block.call(:tag_name)
              raise VcsActionError, "tag name cannot be empty" if is_empty?(tag)
            end

            if is_empty?(msg)
              if block
                msg = block.call(:tag_message, { tag: tag })
              end
            end

            cp "tagged with name : #{tag} and message : #{msg}"
            st, res = @ws.create_tag(tag, msg)
            if st
              block.call(:tagging_success, { tag: tag, output: res }) if block
            else
              block.call(:tagging_failed, { tag: tag, output: res }) if block
            end

            [st, res]

          else

            block.call(:no_tagging_required) if block
            [true, "No tagging required"]
          end

        end

        def push(remote = nil, branch= nil, &block)
         
          remoteConf = @ws.remote_config
          if is_empty?(remoteConf)
            if block
              remote = block.call(:no_remote_repos_defined)
            end
          else
            if is_empty?(remote)
              if block
                remote = block.call(:select_remote, remoteConf)
              else
                remote = remoteConf.keys.first
              end
            end
          end

          raise VcsActionError, "Push repository remote cannot be empty" if is_empty?(remote)

          if remote != :skip

            branch = @ws.current_branch if is_empty?(branch)


            if is_local_ahead_of_remote?("#{remote}/#{branch}", branch)

              cp "pushing to #{remote}/#{branch}"
              st, res = @ws.push_changes_with_tags(remote, branch)

              if st
                block.call(:push_successful, res) if block
              else
                block.call(:push_failed, res) if block
              end

              [st, res]

            else
              block.call(:no_changes_to_push, { remote: remote, branch: branch }) if block
            end
          end

        end

        def add_to_staging(*files)
          @ws.add_to_staging(*files) 
        end

        def add_to_staging_if_commit_before(*files)

          stgDir, stgFiles = @ws.staged_files
          modDir, modFiles = @ws.modified_files
          #newDir, newFiles = @ws.new_files
          delDir, delFiles = @ws.deleted_files

          mFiles = modFiles.map { |e| e.path }
          sFiles = stgFiles.map { |e| e.path }
          dFiles = delFiles.map { |e| e.path }

          res = []
          files.each do |f|
            if (mFiles.include?(f) or dFiles.include?(f)) and not sFiles.include?(f)
              res << f
            end
          end

          if not_empty?(res)
            @ws.add_to_staging(*res)
          end

        end


        private
        def method_missing(mtd, *args, &block)
          if @ws.respond_to?(mtd)
            @ws.send(mtd, *args, &block)
          else
            if not @engine.nil? and @engine.respond_to?(mtd)
              @engine.send(mtd, *args, &block)
            else
              super
            end
          end
        end

        def cp(msg)
          Gem.cul(@ui, msg)
        end
        def ce(msg)
          Gem.cue(@ui, msg)
        end



      end # class VcsAction

    end # module Action

  end # module Gem

end # module Release
