
#require 'rake'
require "bundler/gem_tasks"
#require "rspec/core/rake_task"
require 'yaml'
require_relative 'gemdep'

module Release
  module Gem
    module Action

      class GemActionError < StandardError; end

      class GemAction
        include TR::CondUtils
        include TR::VUtils

        attr_accessor :ui

        def initialize(root, opts = {  })
          raise GemActionError, "root is not given" if is_empty?(root)
          @root = root
          oopts = opts || {}
          @ui = oopts[:ui]
          @engine = oopts[:engine]
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def release_dependencies(*args, &block)

          if gemdepInst.has_development_gem?

            if block

              block.call(:action_start, :relase_dependencies)

              gemdepInst.development_gem.each do |k,v|
                gemdepInst.infect_gem(v, k, &block)
                block.call(:block_until_dev_gem_done, { name: k, path: v })
              end
              

              keys = gemdepInst.development_gem.keys
              loop do
                begin
                  conf = block.call(:define_gem_prod_config, { gems: keys })
                  if conf.is_a?(Hash)
                    conf.each do |k,v|
                      gemdepInst.configure_gem(k,v)
                    end
                    break if gemdepInst.all_dev_gems_has_config? 
                    keys = gemdepInst.not_configured_gem
                  else
                    block.call(:invalid_gem_prod_config, "Expected return from :define_gem_prod_config is a hash of \"gem name\" => { type: [:runtime | :dev], version: \">= 1.2.0\" }. Note version can be empty")
                  end
                rescue GemDepError => ex
                  block.call(:invlid_gem_prod_config, ex.message)
                end
              end

              gemdepInst.transfer_gem

              block.call(:development_gem_temporary_promoted)
            end

          else
            if block
              block.call(:no_development_gems_found)
            end

          end

        end

        def dependency_restore
          puts "restoring dependency"
          gemdepInst.restore_dev_gem 
        end

        def build(*args, &block)

          block.call(:action_start, :build) if block
          cp "Action 'build' starting at #{Gem.format_dt(Time.now)}"

          verfile = find_version_file(&block)
          curVer = find_gem_version(verfile) 
          possVer = possible_versions(curVer)

          cp  "Selection of version number. Current version : #{curVer}"
          if block
            @selVersion = block.call(:select_version, { current_version: curVer, proposed_next: possVer }) 

          else
            @selVersion = possVer[2] # increase last number
            cp "System selected version '#{@selVersion}' since no block is given"
          end

          raise GemActionError, "Version number cannot be blank" if is_empty?(@selVersion)

          cp  "Given version number : #{@selVersion}. Updating gem version file"
          update_gem_version(@selVersion) do |ops, *args|
            if block
              block.call(ops,*args)
            else
              # no block
              case ops
              when :multiple_version_files_found
                sel = args.first.first
                cp  "System selected version file '#{sel}' since no block is given"
                sel
              end
            end
          end

          cp "Gem version updated. Start building the gem"
          begin
            Rake::Task["build"].execute

            if $?
              cp "Gem build successfully at #{Gem.format_dt(Time.now)}"

              if block
                block.call(:gem_build_successfully, @selVersion)
              else
                [true, @selVersion]
              end
            else
              cp "Gem build failed"
              block.call(:gem_build_failed) if block
              [false, ""]
            end
          rescue Exception => ex
            cp "Gem build failed with message : #{ex.message}"
            block.call(:gem_build_failed, ex) if block
          end

        end # build()

        def push(*args, &block)

          opts = args.first || {}

          name = opts[:name]
          name = gemspec.name if is_empty?(name)
          version = opts[:version]
          version = @selVersion if is_empty?(version)

          raise GemActionError, "Version not given and no block" if not block and is_empty?(version)
          if is_empty?(version) and block
            version = block.call(:push_gem_version)
          end

          raise GemActionError, "No version given to push. Push aborted" if is_empty?(version)

          cred = find_rubygems_api_key

          selAcct = cred.keys.first
          if cred.keys.length > 1
            Gem.logger.debug "Multiple rubygems account detected."
            # multiple account configured...
            if block
              selAcct = block.call(:multiple_rubygems_account, cred)
              raise GemActionError, "No rubygems account is selected." if is_empty?(selAcct)
            end
          end


          # find the package
          foundGem = Dir.glob(File.join(@root,"**/#{name}-#{version}*.gem"))
          if foundGem.length == 0
            raise GemActionError, "No built gem with version '#{version}' found."
          elsif foundGem.length > 1
            if block
              targetGem = block.call(:multiple_built_gems, foundGem)
            else
              raise GemActionError, "#{foundGem.length} versions of gem found. Please provide a block for selection"
            end
          else
            targetGem = foundGem.first
          end

          cmd = "cd #{@root} && gem push #{targetGem} -k #{selAcct}"
          Gem.logger.debug "Command to publish gem : #{cmd}"  
          res = `#{cmd} 2>&1`
          block.call(:gem_push_output, $?, res) if block
          [$?, res]

        end

        def install(*args, &block)
          opts = args.first || {}
          gemVer = ""
          if is_empty?(opts)
            if is_empty?(@selVersion)
              raise GemActionError, "No version info is available and no block given" if not block
              gemVer = block.call(:gem_version_to_install) 
              raise GemActionError, "No version info is available" if is_empty?(gemVer)
            else
              gemVer = @selVersion
            end

          else
            gemVer = opts[:version] 
          end

          cp "Given gem version '#{gemVer}' to install"
          res = TTY::Command.new.run!("gem install pkg/#{gemspec.name}-#{gemVer}.gem") do |out, err|
            cp out if not_empty?(out)
            ce err if not_empty?(err)
          end

        end # install


        def update_gem_version(newVersion, version_file = nil, &block)

          raise GemActionError, "block is required" if not block

          if is_empty?(version_file)
            selVerFile = find_version_file(&block)
            raise GemActionError, "Cannot find version file from #{@root}" if is_empty?(selVerFile)
          else
            selVerFile = version_file
          end

          tmpFile = File.join(File.dirname(selVerFile),"version-da.bak")
          FileUtils.mv(selVerFile,tmpFile)

          File.open(selVerFile,"w") do |f|
            File.open(tmpFile,"r").each_line do |l|
              if l =~ /VERSION/
                indx = (l =~ /=/)
                ll = "#{l[0..indx]} \"#{newVersion}\""
                f.puts ll
              else
                f.write l
              end
            end
          end

          FileUtils.rm(tmpFile)

          selVerFile

        end # update_gem_version

        # have to resort to manual way since the version file has 
        # frozen_string_literal which makes the Gem::Specification 
        # always keep the version that it is first loaded
        def find_gem_version(file = nil, &block)

          if is_empty?(file)
            raise GemActionError, "Version file not given to extract version" if not block
            file = find_version_file(&block)
          end

          version = nil
          cont = File.read(file)
          if cont =~ /VERSION/ 
            val = $'
            if not_empty?(val)
              version = val.gsub("=","").gsub("\"","").gsub("end","").strip
            end
          end
          version

        end # find_gem_version


        ### 
        # Private section
        ###
        private
        def cp(msg)
          Gem.cul(@ui, msg)
        end
        def ce(msg)
          Gem.cue(@ui, msg)
        end

        def gemspec
          if @_gemSpec.nil?
            @_gemSpec = ::Gem::Specification.load(Dir.glob(File.join(@root,"*.gemspec")).first)
          end
          @_gemSpec
        end # gemspec

        def find_version_file(&block)

          version_file = Dir.glob(File.join(@root,"**/version.rb"))

          selVerFile = version_file.first
          if version_file.length > 1
            if block
              selVerFile = block.call(:multiple_version_files_found, version_file)
              block.call(:abort) if is_empty?(selVerFile)
            else
              selVerFile = version_file.first
              cp("Multiple version files detected but no block. Using first version file found : '#{selVerFile}'")
            end
          end

          selVerFile
          
        end # find_version_file


        def find_rubygems_api_key
          if TR::RTUtils.on_windows?
            credFile = File.join(ENV['USERPROFILE'],".gem","credentials")
          else
            credFile = File.join(Dir.home,".local","share","gem","credentials")
          end

          raise GemActionError, "Credential file not found at '#{credFile}'" if not File.exist?(credFile)

          cred = nil
          File.open(credFile,"r") do |f|
            cred = YAML.load(f.read)
          end

          raise GemActionError, "Credential file is empty" if is_empty?(cred)
          raise GemActionError, "No credential created yet for rubygems." if is_empty?(cred.keys)

          cred
        end

        def method_missing(mtd, *args, &block)
          if not @engine.nil? 
            @engine.send(mtd, *args, &block)
          else
            super
          end
        end

        def gemdepInst
          if @gemdepInst.nil?
            @gemdepInst = GemDep.new(@root)
          end
          @gemdepInst
        end


      end
    end
  end
end
