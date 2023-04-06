
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
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def release_dependencies
          puts "CLI release dependencies"
          @inst.release_dependencies
        end

        def build(*pargs, &block)

          @inst.build do |ops, *args|
            case ops
            when :action_start
              @pmt.say " Gem building starting...\n".yellow
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
                res = @pmt.select("\n Please select new gem version : \n".yellow) do |m|
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
                    res = @pmt.ask("\n Please provide custom version number for the release : ".yellow,required: true)
                    confirmed = @pmt.yes?("\n Use version '#{res}'? No to try again")
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

                res = @pmt.select("\n There are multiple version file found. Please select which one to update : ".yellow) do |m|
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
              @pmt.puts "\n Gem version '#{args.first}' built successfully".green
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
              res = @pmt.select("\n Multiple rubygems account detected. Please select one : ".yellow) do |m|
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
                @pmt.puts "\n Gem push successful.".green
              else
                @pmt.puts "\n Gem push failed. Error was :\n #{res}".red
              end
            end
          end

        end # push

        def install(*args, &block)

          sysInst = @pmt.yes?("\n Install release into system? ".yellow)
          if sysInst
            @inst.install(*args)
          end

        end # install

        def method_missing(mtd, *args, &block)
          @inst.send(mtd,*args, &block)
        end

      end
    end
  end
end

