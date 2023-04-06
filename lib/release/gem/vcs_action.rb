
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
                msg = block.call(:tag_message)
              end
            end

            cp "tagged with name : #{tag} and message : #{msg}"
            st, res = @ws.create_tag(tag, msg)
            if st
              block.call(:tagging_success, res) if block
            else
              block.call(:tagging_failed, res) if block
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

        def ignore(*files)
          @ws.ignore(*files) 
        end

        def remove_from_staging(*files)
          @ws.remove_from_staging(*files) 
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
