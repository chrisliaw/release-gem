#!/usr/bin/env ruby

require 'release/gem'

puts "\n Standard GEM CLI release flow version #{Release::Gem::VERSION}".yellow
puts "\n Your current location : #{Dir.getwd}\n".yellow

Release::Gem.engine(:gem, root: Dir.getwd) do

  begin
    # step 1 : run test
    run_test(:rspec) 

    # Reason to put it here is because gem build shall
    # only consider files already inside git system via
    # git ls-files command. Anything new that is not yet
    # check in will not be packup by the gem build process
    vcs_cli_manage_workspace

    # step 2 : check dependency
    gem_cli_release_dependencies 

    # step 3 : build the gem
    st, ver = gem_cli_build

    gem_cli_dependency_restore

    if st
      # step 4, push the gem to rubygems
      gem_cli_push(version: ver)
      gem_cli_install(version: ver)
    end

    vcs_add_to_staging_if_commit_before("Gemfile.lock")
    vcs_add_to_staging(value(:version_file_path))

    vcs_commit("Commit after gem version #{ver} built")

    # step 7 : tag the source code
    vcs_cli_tag( tag: ver )      

    # step 8 : Push the source code
    vcs_cli_push

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





