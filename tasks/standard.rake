

require_relative '../lib/release/gem'
require 'tty/prompt'
require 'colorize'

namespace :gem do
  desc "Release GEM standard workflow (gem-release gem)"
  task :release do
    # check for local flow
    custom = Dir.glob(File.join(Dir.getwd, "*.relflow"))
    if custom.length > 0
      
      pmt = TTY::Prompt.new
     
      begin
        if custom.length > 1
          sel = pmt.select("\n There are more than 1 release flow (*.relflow files) detected. Please select one for this session : ".yellow) do |m|
            custom.each do |f|
              m.choice f, f
            end
          end

          require sel

        else
  
          #require custom.first
          load custom.first

        end
      rescue TTY::Reader::InputInterrupt => ex
        pmt.puts "\n Aborted"
      end
    else
      stdFlow = File.join(File.dirname(__FILE__),"..","templates","standard_cli_flow")
      require stdFlow
    end
  end

  #desc "Release test"
  #task :test_release do
  #  stdFlow = File.join(File.dirname(__FILE__),"..","templates","standard_flow")
  #  require stdFlow
  #end

  desc "Copy the standard flow to project local so modification of the flow is possible"
  task :customize_flow do
    stdFlow = File.join(File.dirname(__FILE__),"..","templates","standard_cli_flow.rb")
    dest = File.join(Dir.getwd, "custom_flow.relflow")
    FileUtils.cp stdFlow, dest 
    puts "\n Standard flow copied to #{dest}\n".green
  end

end

