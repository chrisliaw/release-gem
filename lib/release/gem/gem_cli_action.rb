
require 'tty/prompt'
require_relative 'gem_action'

module Release
  module Gem
    module Cli
      class GemAction

        def initialize(root, opts = {})
          opts = {  } if opts.nil?
          opts[:ui] = TTY::Prompt.new
          @inst = Action::GemAction.new(root, opts)
          @pmt = opts[:tty] || opts[:ui]
          @msgColor = opts[:msgColor] || :yellow 
          @discardColor = opts[:discardColor] || false
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def release_dependencies
          @inst.release_dependencies do |ops, *args|
            case ops
            when :action_start
              @pmt.say pmsg("\n Release dependencies starting...\n")

            ## from release_infector
            when :multiple_gemspec
              v = args.first
              @pmt.select(pmsg("\n There are multiple gemspecs found. Please select one to proceed : ")) do |m|
                v.each do |vv|
                  m.choice vv, vv
                end
              end

            when :adding_to_gemspec
              v = args.first
              @pmt.say pmsg("\n Adding release-gem to gemspec '#{v[:gemspec]}'")

            when :gemspec_updated
              v = args.first
              @pmt.say pmsg("\n Gemspec file of GEM '#{v[:name]}' updated with release-gem gem")

            when :adding_to_rackfile
              v = args.first
              @pmt.say pmsg("\n Adding require to Rakefile at #{v[:rakefile]}")

            when :creating_new_rakefile
              v = args.first
              @pmt.say pmsg("\n Creating new Rakefile at #{v[:rakefile]}")

            when :rakefile_updated
              v = args.first
              @pmt.say pmsg("\n Rakefile '#{v[:rakefile]}' updated!")

            when :select_terminal
              v = args.first
              @pmt.select(pmsg("\n Please select a terminal for development GEM '#{v[:name]}' release : ")) do |m|
                v[:options].each do |t|
                  m.choice t, t
                end
              end

            when :new_terminal_launching
              v = args.first
              @pmt.say pmsg("\n New terminal lanching for GEM '#{v[:name]}' using terminal '#{v[:terminal]}'")

            when :new_terminal_launched
              v = args.first
              @pmt.say pmsg("\n New terminal launched for GEM '#{v[:name]}' using terminal '#{v[:terminal]}'")

            when :block_until_dev_gem_done
              v = args.first
              @pmt.yes? pmsg("\n Development GEM '#{v[:name]}' has separate windows for release. Is it done? ")

            ### End release_infector

            when :define_gem_prod_config

              config = {}
              selections = args.first[:gems]

              loop do

                sel = @pmt.select(pmsg("\n The following development gems requires configuration. Please select one to configure ")) do |m|
                  selections.each do |g|
                    m.choice g, g
                  end
                end

                config[sel] = {} if config[sel].nil?

                type = @pmt.select(pmsg("\n The gem in production will be runtime or development ? ")) do |m|
                  m.choice "Runtime", :runtime
                  m.choice "Development only", :dev
                end

                config[sel][:type] = type

                ver = @pmt.ask(pmsg("\n Is there specific version pattern (including the ~>/>/>=/= of gemspec) for the gem in production? (Not mandatory) : "))
                config[sel][:version] = ver if not_empty?(ver)

                @pmt.puts pmsg(" ** Done configure for gem #{sel}")
                selections.delete_if { |v| v == sel }
                break if selections.length == 0

              end

              config

            when :development_gem_temporary_promoted
              @pmt.puts pmsg("\n Development gem(s) temporary promoted to production status")

            when :no_development_gems_found
              @pmt.puts pmsg("\n No development gem(s) in used found")

            end
          end

        end

        def build(*pargs, &block)

          @inst.build do |ops, *args|
            case ops
            when :action_start
              @pmt.say pmsg(" Gem building starting...\n")
            when :select_version
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

                opts = args.first
                res = @pmt.select(pmsg("\n Please select new gem version : \n")) do |m|
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
                    res = @pmt.ask(pmsg("\n Please provide custom version number for the release : "),required: true)
                    confirmed = @pmt.yes?(pmsg("\n Use version '#{res}'? No to try again"))
                    break if confirmed
                  end
                end

              end # if preset

              res

            when :multiple_version_files_found
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

                res = @pmt.select(pmsg("\n There are multiple version file found. Please select which one to update : ")) do |m|
                  opts = args.first
                  opts.each do |f|
                    m.choice f,f
                  end
                  m.choice "Abort", :abort
                end

                raise Release::Gem::Abort, "Abort by user" if res == :abort
              end

              res
            when :new_version_number
              @selVersion = args.first

            when :gem_build_successfully
              @pmt.puts pmsg("\n Gem version '#{args.first}' built successfully", :green)
              @inst.register(:selected_version, args.first)
              [true, args.first]
            end
          end


        end # build

        def push(*pargs, &block)
          @inst.push(*pargs) do |ops, *args|
            case ops
            when :multiple_rubygems_account
              creds = args.first
              res = @pmt.select(pmsg("\n Multiple rubygems account detected. Please select one : ")) do |m|
                creds.each do |k,v|
                  m.choice k,k
                end
                m.choice "Skip gem push", :skip
                m.choice "Abort", :abort
              end

              raise Release::Gem::Abort, "Abort by user" if res == :abort
              res

            when :gem_push_output
              st = pargs.first
              res = pargs[1]
              if st
                @pmt.puts pmsg("\n Gem push successful.", :green)
              else
                @pmt.puts pmsg("\n Gem push failed. Error was :\n #{res}", :red)
              end
            end
          end

        end # push

        def install(*args, &block)

          sysInst = @pmt.yes?(pmsg("\n Install release into system? "))
          if sysInst
            @inst.install(*args)
          end

        end # install

        def method_missing(mtd, *args, &block)
          @inst.send(mtd,*args, &block)
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

