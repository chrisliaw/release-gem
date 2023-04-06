#!/usr/bin/env ruby

require 'release/gem'

puts "\n Standard GEM CLI release flow version #{Release::Gem::VERSION}\n".yellow

Release::Gem.engine(:gem, root: Dir.getwd) do

  begin
    # step 1 : run test
    run_test(:rspec) 

    gem_cli_action do

      # step 2 : check dependency
      release_dependencies 

      # step 3 : build the gem
      st, ver = build

      dependency_restore

      if st
        # step 4, push the gem to rubygems
        push(version: ver)
        install(version: ver)
      end

    end # gem_cli_action


    vcs_cli_action do
      @selVer = value(:selected_version)

      # step 6 : commit vcs
      commit

      # step 7 : tag the source code
      tag( tag: @selVer )      

      # step 8 : Push the source code
      push

    end # vcs_action block
  rescue Release::Gem::Abort => ex
    STDERR.puts "\n -- Aborted by user. Message was : #{ex.message}\n".red
  rescue TTY::Reader::InputInterrupt => ex
  rescue Exception => ex
    STDERR.puts "\n -- Error thrown. Message was : #{ex.message}".red
    STDERR.puts "\n#{ex.backtrace.join("\n")}" if ENV["RELGEM_DEBUG"] == "true"
  ensure 
    gem_dependency_restore
  end

end # Release::Gem::Engine block

puts "\n *** GEM CLI standard release flow done!\n".green





