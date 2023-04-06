

module Release
  module Gem
    
    class ReleaseInfectorError < StandardError; end

    # 
    # Setup the release-gem into other gem project automatically!
    #
    class ReleaseInfector
      include TR::CondUtils
      include TR::TerminalUtils

      def initialize(root, name)
        @root = root
        @name = name
        @backupFiles = {}
      end

      def infect(&block)
        if not is_release_gem_installed?
          add_to_gemspec(&block)
          Bundler.with_clean_env do
            res = `cd #{@root} && bundle update 2>&1`
            puts res
          end
        end

        if not is_rakefile_activated?
          activate_rakefile(&block)
        end
      end

      def trigger_release_gem(&block)

        block.call(:triggering_release_gem) if block

        poss = tu_possible_terminal
        raise ReleaseInfectorError, "No possible terminal found" if is_empty?(poss)

        terminal = ""
        Bundler.with_clean_env do

          cmd = "cd #{@root} && bundle update 2>&1 && rake gem:release" 
          if block
            terminal = block.call(:select_terminal, name: @name, options: poss) if block
            if terminal != :skip
              terminal = poss.first if is_empty?(terminal)

              block.call(:new_terminal_launching, name: @name, terminal: terminal) if block
              tu_new_terminal(terminal, cmd)
            end

          else
            terminal = poss.first
            block.call(:new_terminal_launching, name: @name, terminal: terminal) if block
            tu_new_terminal(terminal, cmd)
          end

          block.call(:new_terminal_launched, name: @name, terminal: terminal) if block

        end

        terminal

      end

      def is_release_gem_installed?
        #Bundler.with_clean_env do
        Bundler.with_unbundled_env do

          res = `cd #{@root} && bundle 2>&1`

          puts res

          if $?.success?
            found = false
            res.each_line do |l|
              if l =~ / release-gem /
                found = true
                break
              end
            end

            found
          else
            raise ReleaseInfectorError, "Error running bundle in '#{@root}'. Error was :\n#{res}"
          end

        end
      end # is_release_gem_installed?

      def add_to_gemspec(&block)
        

        gs = Dir.glob(File.join(@root,"*.gemspec"))
        raise ReleaseInfectorError, "gemspec not found at '#{@root}'" if is_empty?(gs)
        
        block.call(:adding_to_gemspec, gemspec: gs) if block

        if gs.length > 1
          if block
            gs = block.call(:multiple_gemspecs, gs)
          else
            raise ReleaseInfectorError, "There are more than 1 gemspec file found (#{gs.length} found). Since no block to filter out the required one, this will be an error condition"
          end

        else
          gs = gs.first
        end

        cont = File.read(gs) 
        lastEnd = cont.rindex("end")

        FileUtils.mv(gs, "#{gs}.bak")
        @backupFiles[gs] = "#{gs}.bak"

        File.open(gs, "w") do |f|
          f.write cont[0...lastEnd]
          f.puts "  spec.add_development_dependency 'release-gem'"
          f.puts "end"
        end
        block.call(:gemspec_updated, name: @name, gemspec: gs ) if block

      end # add_to_gemspec

      def activate_rakefile(&block)

        rf = File.join(@root,"Rakefile")
        if not File.exist?(rf)
          rfCont <<-END
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

require "release/gem"

RSpec::Core::RakeTask.new(:spec)

task default: :spec
          END
          block.call(:creating_new_rakefile, rakefile: rf ) if block
          File.open(rf,"w") do |f|
            f.write rfCont
          end
        else
          
          block.call(:adding_to_rakefile, rakefile: rf ) if block
         
          cont = File.read(rf)
          FileUtils.mv(rf, "#{rf}.bak")
          @backupFiles[rf] = "#{rf}.bak"

          File.open(rf,"w") do |f|
            f.puts cont
            f.puts "require 'release/gem'"
          end

          block.call(:rakefile_updated, name: @name, rakefile: rf) if block

        end
      end

      def is_rakefile_activated?
        rf = File.join(@root,"Rakefile")
        if not File.exist?(rf)
          false
        else
          cont = File.read(rf)
          found = false
          cont.each_line do |l|
            if l =~ /require ('|")(release\/gem)("|')/
              found = true
              break
            end
          end
          found
        end
      end

    end
  end
end
