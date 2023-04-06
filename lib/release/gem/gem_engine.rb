
require_relative 'vcs_action'
require_relative 'gem_action'

require_relative 'vcs_cli_action'
require_relative 'gem_cli_action'

module Release
  module Gem
    module Engine
      class GemEngine
        include TR::CondUtils

        def initialize(*args, &block)
          opts = args.first
          @root = opts[:root]
          @ui = opts[:ui]
          @var = {}
          
          exec(&block)
        end

        def exec(&block)
          instance_eval(&block) if block
        end

        def run_test(eng)
          puts "run test : #{eng}" 
        end

        def register(key,value)
          @var[key] = value if not_empty?(key) 
        end

        def value(key)
          @var[key]
        end

        def gem_action(&block)
          gem_action_inst.exec(&block) 
        end

        def gem_cli_action(&block)
          gem_cli_action_inst.exec(&block)
        end

        def vcs_action(&block)
          vcs_action_inst.exec(&block) 
        end

        def vcs_cli_action(&block)
          vcs_cli_action_inst.exec(&block) 
        end

        def method_missing(mtd, *args, &block)
          if mtd.to_s.start_with?("gem_cli")
            Gem.logger.debug "Passing method '#{mtd}' to gem_cli action"
            pmtd = mtd.to_s[7..-1].to_sym
            gem_cli_action_inst.send(pmtd, *args, &block)

          elsif mtd.to_s.start_with?("vcs_cli")
            Gem.logger.debug "Passing method '#{mtd}' to vcs_cli action"
            pmtd = mtd.to_s[7..-1].to_sym
            vcs_cli_action_inst.send(pmtd, *args, &block)
 
          elsif mtd.to_s.start_with?("gem_")
            Gem.logger.debug "Passing method '#{mtd}' to gem action"
            pmtd = mtd.to_s[4..-1].to_sym
            gem_action_inst.send(pmtd, *args, &block)

          elsif mtd.to_s.start_with?("vcs_")
            pmtd = mtd.to_s[4..-1].to_sym
            vcs_action_inst.send(pmtd, *args, &block)

          else
            super
          end
        end

        def vcs_action_inst
          if @vcsAct.nil?
            @vcsAct = Action::VcsAction.new(@root,{ ui: @ui, engine: self })
          end
          @vcsAct
        end

        def gem_action_inst
          if @gemAct.nil?
            @gemAct = Action::GemAction.new(@root, { ui: @ui, engine: self})
          end
          @gemAct
        end

        def vcs_cli_action_inst
          if @vcsCliAct.nil?
            @vcsCliAct = Cli::VcsAction.new(@root,{ engine: self })
          end
          @vcsCliAct
        end

        def gem_cli_action_inst
          if @gemCliAct.nil?
            @gemCliAct = Cli::GemAction.new(@root, { engine: self})
          end
          @gemCliAct
        end


      end
    end
  end
end

