
require 'fileutils'

RSpec.describe "Automatically setup release gem into other workspace" do

  it 'test if the release-gem is installed' do
   
    testGemDir = "/mnt/Vault/tmp/testGemDir"
    #path = File.join(Dir.getwd,testGemDir)
    path = testGemDir
    FileUtils.rm_rf(path)
    res = `bundle gem #{path}`
    if $?.success?
      f = Dir.glob(File.join(path,"*.gemspec"))
      f = f.first
      cont = File.read(f)
      #puts cont
      FileUtils.rm(f)
      File.open(f, "w") do |f|
        cont.each_line do |l|
          if l =~ /spec.metadata/
            f.puts "##{l}"
          elsif l =~ /spec.summary/
            f.puts "  spec.summary=\"\""
          elsif l =~ /spec.description/
            f.puts "  spec.description=\"\""
          elsif l =~ /spec.homepage/
            f.puts "  spec.homepage=\"\""
          else
            f.puts l
          end
        end
      end
      #puts File.read(f)
    end

    begin
      inf = Release::Gem::ReleaseInfector.new(path, "localtest")
      expect(inf.is_release_gem_installed?).to be false
      expect(inf.is_rakefile_activated?).to be false

      inf.infect do |ops, *args|
        puts "Ops : #{ops} / #{args}"
      end

      expect(inf.is_release_gem_installed?).to be true
      expect(inf.is_rakefile_activated?).to be true
     
      inf.trigger_release_gem do |ops, *args|
        puts "trigger ops : #{ops} / #{args}"
      end

    rescue Exception => ex
      fail(ex)
    ensure
      #FileUtils.rm_rf(path)
    end

  end

end
