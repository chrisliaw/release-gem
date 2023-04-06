
require 'bundler'

module Release
  module Gem
    
    class GemDepError < StandardError; end

    class GemDep
      include TR::CondUtils

      def initialize(root, opts = {  })
        @root = root
        @discardColor = opts[:discardColor] || false
        @devGems = {}
        @gemConfig = {}
        @fileHistory = {}
        load_gemfile_deps
        load_gemspec_deps
      end

      def load_gemfile_deps
        gdef = Bundler::Definition.build(gemfile_file, nil, {})
        gdef.dependencies.each do |d|
          if not d.source.nil? and d.source.path.to_s != "."
            @devGems[d.name] = d.source.path.to_s
          end
        end
      end

      def load_gemspec_deps
        gs = ::Gem::Specification.load(gemspec_file)
        gs.dependencies.each do |d|
          if not d.source.nil? and d.source.path.to_s != "."
            @devGems[d.name] = d.source.path.to_s
          end
        end
      end

      def has_development_gem?
        not_empty?(@devGems)
      end

      def development_gem
        @devGems
      end

      def configure_gem(name, opts = { type: :runtime, version: "" })
        raise GemDepError, "Given option to configure the gem is empty" if is_empty?(opts)
        raise GemDepError, "Given option is not a hash. Hash wity keys :type and/or :version (can be empty) is expected" if not opts.is_a?(Hash)
        raise GemDepError, "Production gem type not given. Please provide the gem type via key :type (valid value is either :runtime or :dev)" if is_empty?(opts[:type])

        if @devGems.keys.include?(name.to_s) 
          @gemConfig[name.to_s] = opts
        else
          raise GemDepError, "Name '#{name}' is not in the list of development gems. Valid value including : #{@devGems.keys.join(", ")}"
        end
      end

      def transfer_gem
        if not all_dev_gems_has_config?
          raise GemDepError, "Not all gem has configuration. Gem required configuration includes: #{not_configured_gem.join(", ")}"
        end

        remove_dev_gem_from_gemfile
        add_gem_to_gemspec(@gemConfig)

      end

      def all_dev_gems_has_config?
        not_configured_gem.length == 0   
      end

      def not_configured_gem
        @devGems.keys.difference(@gemConfig.keys)
      end

      def restore_dev_gem
        @fileHistory.each do |k,v|
          FileUtils.mv(k,"#{k}.prod")
          FileUtils.cp(v,k)
        end
        @fileHistory.clear
      end

      def infect_gem(gem_root,name, &block)
        ri = ReleaseInfector.new(gem_root, name)
        ri.infect(&block)
        ri.trigger_release_gem(&block)
      end

      private
      def remove_dev_gem_from_gemfile
        if has_development_gem?
          orin = gemfile_file
          dest = "#{gemfile_file}.dev"
          FileUtils.cp(orin, dest)
          @fileHistory[orin] = dest

          tmpOut = "#{orin}.tmp"

          File.open(tmpOut, "w") do |f|
            cont = File.read(dest)
            cont.each_line do |l|
              next if l =~ /^gem ('|")(#{development_gem.keys.join("|")})('|")/
              f.puts l
            end
          end

          FileUtils.rm(orin)
          FileUtils.mv(tmpOut, orin)

          # to make sure has_development_gem? return false in subsequent run
          load_gemfile_deps

        end
      end

      def add_gem_to_gemspec(spec = {})

        if has_development_gem?

          orin = gemspec_file
          dest = "#{gemspec_file}.dev"
          FileUtils.cp(orin, dest)
          @fileHistory[orin] = dest

          tmpOut = "#{orin}.tmp"

          cont = File.read(gemspec_file) 
          lastEnd = cont.rindex("end")
          
          File.open(tmpOut, "w") do |f|
            f.write cont[0...lastEnd]
            spec.each do |k,v|
              case v[:type]
              when :runtime
                f.puts "  spec.add_dependency \"#{k}\"#{is_empty?(v[:version]) ? "" : ", \"#{v[:version]}\""}"
              when :dev
                f.puts "  spec.add_development_dependency \"#{k}\"#{is_empty?(v[:version]) ? "" : ", \"#{v[:version]}\""}"
              end
            end

            f.puts "end"
          end

          FileUtils.rm(orin)
          FileUtils.mv(tmpOut, orin)
          
          # to make sure has_development_gem? return false in subsequent run
          load_gemspec_deps

        end


      end

      def gemspec_file
        if @_gemspec.nil?
          @_gemspec = Dir.glob(File.join(@root,"*.gemspec"))  
          raise GemDepError, "Cannot find gemspec at '#{@root}'" if is_empty?(@_gemspec)
          @_gemspec = @_gemspec.first
        end
        @_gemspec
      end

      def gemfile_file
        if @_gemfile_file.nil?
          @_gemfile_file = Dir.glob(File.join(@root,"Gemfile"))
          raise GemDepError, "Cannot find Gemfile at '#{@root}'" if is_empty?(@_gemfile_file)
          @_gemfile_file = @_gemfile_file.first
        end
        @_gemfile_file
      end

    end
  end
end
